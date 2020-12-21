// Copyright 2020 Apulis Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package deviceplugin

import (
	"context"
	"fmt"
	"net"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	// gRPC is the package for rpc call, this is the core for the device plugin
	"github.com/fsnotify/fsnotify"
	"github.com/pkg/errors"
	"google.golang.org/grpc"

	pluginapi "k8s.io/kubelet/pkg/apis/deviceplugin/v1beta1"

	"github.com/apulis/k8s-device-plugin/cmd/debug"
)

type serverState int

// Server state
const (
	uninitialized serverState = iota
	serving
	terminating
)

// devicePluginServer maintains a gRPC server satisfying
// pluginapi.PluginInterfaceServer interfaces.
// This internal unexposed interface simplifies unit testing.
type devicePluginServer interface {
	Serve(namespace string) error
	Stop() error
	Update(devices map[string]DeviceInfo)
}

// server implements devicePluginServer and pluginapi.PluginInterfaceServer interfaces.
type server struct {
	devType      string
	grpcServer   *grpc.Server
	updatesCh    chan map[string]DeviceInfo
	devices      map[string]DeviceInfo
	postAllocate func(*pluginapi.AllocateResponse) error
	state        serverState
	stateMutex   sync.Mutex
}

// newServer creates a new server satisfying the devicePluginServer interface.
func newServer(devType string, postAllocate func(*pluginapi.AllocateResponse) error) devicePluginServer {
	return &server{
		devType:      devType,
		updatesCh:    make(chan map[string]DeviceInfo, 1), // TODO: is 1 needed?
		devices:      make(map[string]DeviceInfo),
		postAllocate: postAllocate,
		state:        uninitialized,
	}
}

func (srv *server) GetDevicePluginOptions(ctx context.Context, empty *pluginapi.Empty) (*pluginapi.DevicePluginOptions, error) {
	fmt.Println("GetDevicePluginOptions: return empty options")
	return new(pluginapi.DevicePluginOptions), nil
}

func (srv *server) sendDevices(stream pluginapi.DevicePlugin_ListAndWatchServer) error {
	resp := new(pluginapi.ListAndWatchResponse)
	for id, device := range srv.devices {
		resp.Devices = append(resp.Devices, &pluginapi.Device{
			ID:     id,
			Health: device.State,
		})
	}
	debug.Print("Sending to kubelet", resp.Devices)
	if err := stream.Send(resp); err != nil {
		srv.Stop()
		return errors.Wrapf(err, "Cannot update device list")
	}

	return nil
}

func (srv *server) ListAndWatch(empty *pluginapi.Empty, stream pluginapi.DevicePlugin_ListAndWatchServer) error {
	debug.Print("Started ListAndWatch for", srv.devType)

	if err := srv.sendDevices(stream); err != nil {
		return err
	}

	for srv.devices = range srv.updatesCh {
		if err := srv.sendDevices(stream); err != nil {
			return err
		}
	}

	return nil
}

func (srv *server) Allocate(ctx context.Context, rqt *pluginapi.AllocateRequest) (*pluginapi.AllocateResponse, error) {
	var mdev *pluginapi.DeviceSpec
	var devmm *pluginapi.DeviceSpec
	var hisi *pluginapi.DeviceSpec

	npuList := []string{}

	response := new(pluginapi.AllocateResponse)
	for _, crqt := range rqt.ContainerRequests {
		cresp := new(pluginapi.ContainerAllocateResponse)
		for _, id := range crqt.DevicesIDs {
			dev, ok := srv.devices[id]
			if !ok {
				return nil, errors.Errorf("Invalid allocation request with non-existing device %s", id)
			}
			if dev.State != pluginapi.Healthy {
				return nil, errors.Errorf("Invalid allocation request with unhealthy device %s", id)
			}
			for i := range dev.Nodes {
				cresp.Devices = append(cresp.Devices, &dev.Nodes[i])
			}
			for i := range dev.Mounts {
				cresp.Mounts = append(cresp.Mounts, &dev.Mounts[i])
			}
			for key, value := range dev.Envs {
				if cresp.Envs == nil {
					cresp.Envs = make(map[string]string)
				}
				cresp.Envs[key] = value
			}

			re := regexp.MustCompile(`[0-9]+`)
			matches := re.FindStringSubmatch(string(id))
			if len(matches) >= 1 {
				myid := matches[0]
				npuList = append(npuList, myid)
			}

		}

		// No mater which device we choose, we need to send all other devices along the devices
		mdev = new(pluginapi.DeviceSpec)
		mdev.HostPath = "/dev/davinci_manager"
		mdev.ContainerPath = "/dev/davinci_manager"
		mdev.Permissions = "rwm"
		cresp.Devices = append(cresp.Devices, mdev)

		devmm = new(pluginapi.DeviceSpec)
		devmm.HostPath = "/dev/devmm_svm"
		devmm.ContainerPath = "/dev/devmm_svm"
		devmm.Permissions = "rwm"
		cresp.Devices = append(cresp.Devices, devmm)

		hisi = new(pluginapi.DeviceSpec)
		hisi.HostPath = "/dev/hisi_hdc"
		hisi.ContainerPath = "/dev/hisi_hdc"
		hisi.Permissions = "rwm"
		cresp.Devices = append(cresp.Devices, hisi)
		if cresp.Envs == nil {
			cresp.Envs = make(map[string]string)
		}
		cresp.Envs["VISIBLE_IDS"] = strings.Join(npuList, ",")

		response.ContainerResponses = append(response.ContainerResponses, cresp)
	}

	if srv.postAllocate != nil {
		err := srv.postAllocate(response)
		if err != nil {
			return nil, err
		}
	}
	return response, nil
}

func (srv *server) PreStartContainer(ctx context.Context, rqt *pluginapi.PreStartContainerRequest) (*pluginapi.PreStartContainerResponse, error) {
	return nil, errors.New("PreStartContainer() should not be called")
}

// Serve starts a gRPC server to serve pluginapi.PluginInterfaceServer interface.
func (srv *server) Serve(namespace string) error {
	return srv.setupAndServe(namespace, pluginapi.DevicePluginPath, pluginapi.KubeletSocket)
}

// Stop stops serving pluginapi.PluginInterfaceServer interface.
func (srv *server) Stop() error {
	if srv.grpcServer == nil {
		return errors.New("Can't stop non-existing gRPC server. Calling Stop() before Serve()?")
	}
	srv.setState(terminating)
	srv.grpcServer.Stop()
	close(srv.updatesCh)
	return nil
}

// Update sends updates from Manager to ListAndWatch's event loop.
func (srv *server) Update(devices map[string]DeviceInfo) {
	srv.updatesCh <- devices
}

func (srv *server) setState(state serverState) {
	srv.stateMutex.Lock()
	defer srv.stateMutex.Unlock()
	srv.state = state
}

func (srv *server) getState() serverState {
	srv.stateMutex.Lock()
	defer srv.stateMutex.Unlock()
	return srv.state
}

// setupAndServe binds given gRPC server to device manager, starts it and registers it with kubelet.
func (srv *server) setupAndServe(namespace string, devicePluginPath string, kubeletSocket string) error {
	resourceName := namespace + "/" + srv.devType
	pluginPrefix := namespace + "-" + srv.devType
	srv.setState(serving)

	for srv.getState() == serving {
		pluginEndpoint := pluginPrefix + ".sock"
		pluginSocket := path.Join(devicePluginPath, pluginEndpoint)

		if err := waitForServer(pluginSocket, time.Second); err == nil {
			return errors.Errorf("Socket %s is already in use", pluginSocket)
		}
		os.Remove(pluginSocket)

		lis, err := net.Listen("unix", pluginSocket)
		if err != nil {
			return errors.Wrap(err, "Failed to listen to plugin socket")
		}

		srv.grpcServer = grpc.NewServer()
		pluginapi.RegisterDevicePluginServer(srv.grpcServer, srv)

		// Starts device plugin service.
		go func() {
			fmt.Printf("Start server for %s at: %s\n", srv.devType, pluginSocket)
			srv.grpcServer.Serve(lis)
		}()

		// Wait for the server to start
		if err = waitForServer(pluginSocket, 10*time.Second); err != nil {
			return err
		}

		// Register with Kubelet.
		err = registerWithKubelet(kubeletSocket, pluginEndpoint, resourceName)
		if err != nil {
			return err
		}
		fmt.Printf("Device plugin for %s registered\n", srv.devType)

		// Kubelet removes plugin socket when it (re)starts
		// plugin must restart in this case
		if err = watchFile(pluginSocket); err != nil {
			return err
		}

		if srv.getState() == serving {
			srv.grpcServer.Stop()
			fmt.Printf("Socket %s removed, restarting\n", pluginSocket)
		} else {
			fmt.Printf("Socket %s shut down\n", pluginSocket)
		}
	}

	return nil
}

func watchFile(file string) error {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return errors.Wrapf(err, "Failed to create watcher for %s", file)
	}
	defer watcher.Close()

	err = watcher.Add(filepath.Dir(file))
	if err != nil {
		return errors.Wrapf(err, "Failed to add %s to watcher", file)
	}

	for {
		select {
		case ev := <-watcher.Events:
			if (ev.Op == fsnotify.Remove || ev.Op == fsnotify.Rename) && ev.Name == file {
				return nil
			}
		case err := <-watcher.Errors:
			return errors.WithStack(err)
		}
	}
}

func registerWithKubelet(kubeletSocket, pluginEndPoint, resourceName string) error {
	conn, err := grpc.Dial(kubeletSocket, grpc.WithInsecure(),
		grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
			return net.DialTimeout("unix", addr, timeout)
		}))
	if err != nil {
		return errors.Wrap(err, "Cannot connect to kubelet service")
	}
	defer conn.Close()
	client := pluginapi.NewRegistrationClient(conn)
	reqt := &pluginapi.RegisterRequest{
		Version:      pluginapi.Version,
		Endpoint:     pluginEndPoint,
		ResourceName: resourceName,
	}

	_, err = client.Register(context.Background(), reqt)
	if err != nil {
		return errors.Wrap(err, "Cannot register to kubelet service")
	}

	return nil
}

// waitForServer checks if grpc server is alive
// by making grpc blocking connection to the server socket
func waitForServer(socket string, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	conn, err := grpc.DialContext(ctx, socket, grpc.WithInsecure(), grpc.WithBlock(),
		grpc.WithDialer(func(addr string, timeout time.Duration) (net.Conn, error) {
			return net.DialTimeout("unix", addr, timeout)
		}),
	)
	if conn != nil {
		conn.Close()
	}
	return errors.Wrapf(err, "Failed dial context at %s", socket)
}
