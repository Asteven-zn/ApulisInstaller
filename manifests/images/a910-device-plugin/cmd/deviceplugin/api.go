// Copyright 2018 Apulis Inc. All Rights Reserved.
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

// It was moved from k8s.io/kubenetes/pkg/kublet/apis/deviceplug/v1beta1
import (
	pluginapi "k8s.io/kubelet/pkg/apis/deviceplugin/v1beta1"
)

// DeviceInfo contains information about device maintained by Device Plugin
type DeviceInfo struct {
	State  string
	Nodes  []pluginapi.DeviceSpec
	Mounts []pluginapi.Mount
	Envs   map[string]string
}

// DeviceTree contains a tree-like structure of device type -> device ID -> device info.
type DeviceTree map[string]map[string]DeviceInfo

// NewDeviceTree creates an instance of DeviceTree
func NewDeviceTree() DeviceTree {
	return make(map[string]map[string]DeviceInfo)
}

// AddDevice adds device info to DeviceTree.
func (tree DeviceTree) AddDevice(devType, id string, info DeviceInfo) {
	if _, present := tree[devType]; !present {
		tree[devType] = make(map[string]DeviceInfo)
	}
	tree[devType][id] = info
}

// Notifier receives updates from Scanner, detects changes and sends the
// detected changes to a channel given by the creator of a Notifier object.
type Notifier interface {
	// Notify notifies manager with a device tree constructed by device
	// plugin during scanning process.
	Notify(DeviceTree)
}

// Scanner serves as an interface between Manager and a device plugin.
type Scanner interface {
	// Scan scans the host for devices and sends all found devices to
	// a Notifier instance. It's called only once for every device plugin by
	// Manager in a goroutine and operates in an infinite loop.
	Scan(Notifier) error
}

// PostAllocator is an optional interface implemented by device plugins.
type PostAllocator interface {
	// PostAllocate modifies responses returned by Allocate() by e.g.
	// adding annotations consumed by CRI hooks to the responses.
	PostAllocate(*pluginapi.AllocateResponse) error
}
