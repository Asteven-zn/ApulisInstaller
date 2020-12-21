#!/usr/bin/python
# Copyright (c) Microsoft Corporation
# All rights reserved.
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
# to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import argparse
import urllib.parse
import os
import json
import sys
import requests
import logging
import time
import threading
import signal
import faulthandler
import gc
import re
import collections
import datetime
import math
import json
import subprocess
from operator import add
import yaml
import prometheus_client
from prometheus_client import Counter, Summary, Histogram
from prometheus_client.core import GaugeMetricFamily, CounterMetricFamily, Summary, REGISTRY
from prometheus_client.twisted import MetricsResource

from twisted.web.server import Site
from twisted.web.resource import Resource
from twisted.internet import reactor

logger = logging.getLogger(__name__)


##### watchdog will generate following metrics
# Document about these metrics is in `prometheus/doc/watchdog-metrics.md`

error_counter = Counter("process_error_log_total", "total count of error log", ["type"])

api_healthz_histogram = Histogram("k8s_api_healthz_resp_latency_seconds",
        "Response latency for requesting k8s api healthz (seconds)")

# use `histogram_quantile(0.95, sum(rate(k8s_api_list_pods_latency_seconds_bucket[5m])) by (le))`
# to get 95 percentile latency in past 5 miniute.
list_pods_histogram = Histogram("k8s_api_list_pods_latency_seconds",
        "Response latency for list pods from k8s api (seconds)")

list_nodes_histogram = Histogram("k8s_api_list_nodes_latency_seconds",
        "Response latency for list nodes from k8s api (seconds)")

list_vc_quota_histogram = Histogram("list_vc_quota_latency_seconds",
        "Response latency for list vc quota from restful api (seconds)")

def gen_pai_pod_gauge():
    return GaugeMetricFamily("pai_pod_count", "count of pai pod",
            labels=["service_name", "name", "namespace", "phase", "host_ip",
                "initialized", "pod_scheduled", "ready"])

def gen_job_pod_gauge():
    return GaugeMetricFamily("job_pod_count", "count of job pod",
            labels=["job_id", "name", "namespace", "phase", "host_ip",
                "initialized", "pod_scheduled", "ready"])

def gen_pai_container_gauge():
    return GaugeMetricFamily("pai_container_count", "count of container pod",
            labels=["service_name", "pod_name", "name", "namespace", "state",
                "host_ip", "ready"])

def gen_pai_node_gauge():
    return GaugeMetricFamily("pai_node_count", "count of pai node",
            labels=["name", "disk_pressure", "memory_pressure", "out_of_disk", "ready", "unschedulable","deviceType"])

def gen_k8s_api_gauge():
    return GaugeMetricFamily("k8s_api_server_count", "count of k8s api server",
            labels=["error", "host_ip"])

def gen_gauge_node_device_total():
    return GaugeMetricFamily("k8s_node_device_total", "device capacity on k8s node",
            labels=["host_ip","device_type","device_str"])

def gen_gauge_node_device_available():
    return GaugeMetricFamily("k8s_node_device_available", "device available on k8s node",
            labels=["host_ip","device_type","device_str"])

def gen_gauge_node_device_used():
    return GaugeMetricFamily("k8s_node_device_used", "device used on k8s node",
            labels=["host_ip","device_type","device_str"])

def gen_gauge_node_preemptable_device_available():
    return GaugeMetricFamily("k8s_node_preemptable_device_available",
            "device available on k8s node for preemptable job",
            labels=["host_ip","device_type","device_str"])

def gen_k8s_node_device_allocatable():
    return GaugeMetricFamily("k8s_node_device_allocatable",
            "gpu allocatable on k8s node, this include used allocatable",
            labels=["host_ip","device_type","device_str"])

def gen_gauge_node_device_reserved():
    return GaugeMetricFamily("k8s_node_device_reserved",
            "device reserved on k8s node",
            labels=["host_ip","device_type","device_str"])

service_response_histogram = Histogram("service_response_latency_seconds",
            "response latency of each service",
            labelnames=("service_name", "service_ip"),
            buckets=(.1, .5, 1.0, 2.0, 4.0, 6.0, 8.0, 10.0, 16.0, 32.0, float("inf")))

service_response_counter = Counter("service_response_code",
        "total count of http return code", ["service_name", "service_ip", "code"])

def gen_k8s_vc_device_total():
    return GaugeMetricFamily("k8s_vc_device_total", "device total in vc",
            labels=["vc_name", "device_str"])

def gen_k8s_vc_device_unschedulable():
    return GaugeMetricFamily("k8s_vc_device_unschedulable", "device unschedulable in vc",
            labels=["vc_name", "device_str"])

def gen_k8s_vc_device_available():
    return GaugeMetricFamily("k8s_vc_device_available",
            "device available for non preemptable job in vc",
            labels=["vc_name", "device_str"])

def gen_k8s_vc_device_preemptive_available():
    return GaugeMetricFamily("k8s_vc_device_preemptive_availabe",
            "device available for preemptable job in vc",
            labels=["vc_name", "device_str"])

##### watchdog will generate above metrics

def walk_json_field_safe(obj, *fields):
    """ for example a=[{"a": {"b": 2}}]
    walk_json_field_safe(a, 0, "a", "b") will get 2
    walk_json_field_safe(a, 0, "not_exist") will get None
    """
    try:
        for f in fields:
            obj = obj[f]
        return obj
    except:
        return None

def convert_to_byte(data):
    data = data.lower()
    number = float(re.findall(r"[0-9.]+", data)[0])
    if "t" in data:
        return number * 10 ** 12
    elif "g" in data:
        return number * 10 ** 9
    elif "m" in data:
        return number * 10 ** 6
    elif "k" in data:
        return number * 10 ** 3
    elif "ti" in data:
        return number * 2 ** 40
    elif "gi" in data:
        return number * 2 ** 30
    elif "mi" in data:
        return number * 2 ** 20
    elif "ki" in data:
        return number * 2 ** 10
    else:
        return number

class ResourceMark(object):

    label_huawei_npu = "npu.huawei.com/NPU"
    label_nvidia_gpu = "nvidia.com/gpu"
    resource_mark_list = [label_huawei_npu, label_nvidia_gpu]

    @staticmethod
    def is_npu_resource(mark):
        return mark.strip().lower() == ResourceMark.label_huawei_npu.strip().lower()

    @staticmethod
    def is_gpu_resource(mark):
        return mark.strip().lower() == ResourceMark.label_nvidia_gpu.strip().lower()

class AtomicRef(object):
    """ a thread safe way to store and get object,
    should not modify data get from this ref,
    each get and set method should provide a time obj,
    so this ref decide whether the data is out of date or not,
    return None on expired """
    def __init__(self, decay_time):
        self.data = None
        self.date_in_produced = datetime.datetime.now()
        self.decay_time = decay_time
        self.lock = threading.RLock()

    def set(self, data, now):
        with self.lock:
            self.data, self.date_in_produced = data, now

    def get(self, now):
        with self.lock:
            if self.date_in_produced + self.decay_time < now:
                return None
            return self.data


class CustomCollector(object):
    def __init__(self, atomic_refs):
        self.atomic_refs = atomic_refs

    def collect(self):
        data = []

        now = datetime.datetime.now()

        for ref in self.atomic_refs:
            d = ref.get(now)
            if d is not None:
                data.extend(d)

        if len(data) > 0:
            for datum in data:
                yield datum
        else:
            # https://stackoverflow.com/a/6266586
            # yield nothing
            return
            yield


def catch_exception(fn, msg, default, *args, **kwargs):
    """ wrap fn call with try catch, makes watchdog more robust """
    try:
        return fn(*args, **kwargs)
    except Exception as e:
        error_counter.labels(type="parse").inc()
        logger.exception(msg)
        return default

class PodInfo(object):
    def __init__(self, name, preemptable, used_processor, resource_mark):

        self.name = name
        self.preemptable = preemptable
        self.used_processor = used_processor
        self.resource_mark = resource_mark

    def __repr__(self):
        return "%s, %s, %s, %s" % (self.name, self.preemptable, self.used_processor, self.resource_mark)

def process_service_endpoints(service_name, host_ip, annotations, service_endpoints):
    annotation_ns = "monitor.watchdog"
    port_key = annotation_ns + "/port"
    path_key = annotation_ns + "/path"
    timeout_key = annotation_ns + "/timeout"

    if port_key in annotations and path_key in annotations:
        try:
            port = int(annotations[port_key])
        except ValueError:
            logger.warning("illegal value %s in %s, expect port",
                    annotations[port_key], port_key)
            return

        path = annotations[path_key]

        timeout = 10 # default
        if annotations.get(timeout_key) is not None:
            try:
                timeout = int(annotations.get(timeout_key))
            except ValueError:
                logger.warning("illegal value %s in %s, expect int. Ignore it",
                        annotations[timeout_key], timeout_key)

        service_endpoints.append(
                ServiceEndpoint(service_name, host_ip, port, path, timeout))


def parse_pod_item(pod, pai_pod_gauge, pai_container_gauge, pods_info, service_endpoints, vc_usage,job_pod_gauge):
    """ add metrics to pai_pod_gauge or pai_container_gauge if successfully paesed pod.
    Because we are parsing json outputed by k8s, its format is subjected to change,
    we should test if field exists before accessing it to avoid KeyError """

    logger.debug("calling parse_pod_item")

    pod_name = pod["metadata"]["name"]
    namespace = walk_json_field_safe(pod, "metadata", "namespace") or "default"
    host_ip = walk_json_field_safe(pod, "status", "hostIP") or "unscheduled"

    preemptable_str = walk_json_field_safe(pod, "metadata", "labels", "preemptionAllowed") or False
    preemptable = preemptable_str == "True" or preemptable_str == "true"

    using_gpu = True
    using_npu = True
    using_processor = True

    # one precondition here: 
    # for one server, there sould be only one type of processor
    used_processor = 0  
    resource_mark = ResourceMark.label_nvidia_gpu

    containers = walk_json_field_safe(pod, "spec", "containers")
    if containers is not None:
        for container in containers:    

            ## loop through resource mark list 
            for mark in ResourceMark.resource_mark_list:

                ## process gpu info
                req_processor = int(walk_json_field_safe(container, "resources", "requests", mark) or 0)
                limit_processor = int(walk_json_field_safe(container, "resources", "limits", mark) or 0)
                used_processor += max(req_processor, limit_processor)

                phase = walk_json_field_safe(pod, "status", "phase")
                if phase == "Succeeded" or phase == "Failed":
                    using_processor = False
                else:
                    pass

                if req_processor > 0:
                    ## matched
                    ## set resource type
                    resource_mark = mark
                    logger.debug("found resource: %s" % mark)
                    break
                else:
                    ## mark doesn't match the label info from container
                    continue
    else:
        pass

    # save used_gpus to pod_info which will be used later
    # in parse_node_status for computing gpus/npus
    vc = walk_json_field_safe(pod, "metadata", "labels", "vcName")
    if vc is not None and preemptable is not None and using_processor:

        pods_info[host_ip].append(PodInfo(pod_name, preemptable, used_processor, resource_mark))
        gpu_type = walk_json_field_safe(pod, "metadata", "labels", "gpuType")

        logger.debug("append pod resource. pod name[%s], preemptable[%d], used_processor[%d], resource_mark[%s]" % 
                    (pod_name, preemptable, used_processor, resource_mark))

        # for huawei, gpu_type=Huawei_A910
        # for nvidia, gpu_type=nvidia
        if gpu_type is None:
            gpu_type = ""
        else:
            pass

        logger.debug("append pod resource. pod name[%s], gpu_type[%s], used_processor[%d]" % (pod_name, gpu_type, used_processor))
        if preemptable:
            vc_usage.add_preemptable_used(vc, gpu_type, used_processor)
        else:
            vc_usage.add_used(vc, gpu_type, used_processor)
    else:
        pass

    labels = pod["metadata"].get("labels")
    isJob = False
    if labels is None or ("app" not in labels and "jobId" not in labels):
        logger.info("unknown pod %s", pod["metadata"]["name"])
        return None
    elif "jobId" in labels:
        service_name = labels["jobId"]
        isJob = True
    else:
        service_name = labels["app"] # get pai service name from label


    annotations = walk_json_field_safe(pod, "metadata", "annotations") or {}

    if host_ip != "unscheduled":
        process_service_endpoints(service_name, host_ip, annotations, service_endpoints)

    status = pod["status"]

    if status.get("phase") is not None:
        phase = status["phase"].lower()
    else:
        phase = "unknown"

    initialized = pod_scheduled = ready = ContainersReady = "unknown"

    conditions = status.get("conditions")
    if conditions is not None:
        for cond in conditions:
            cond_t = cond["type"] # Initialized|Ready|PodScheduled
            cond_status = cond["status"].lower()

            if cond_t == "Initialized":
                initialized = cond_status
            elif cond_t == "PodScheduled":
                pod_scheduled = cond_status
            elif cond_t == "Ready":
                ready = cond_status
            elif cond_t == "ContainersReady":
                ContainersReady = cond_status
            else:
                error_counter.labels(type="unknown_pod_cond").inc()
                logger.error("unexpected condition %s in pod %s", cond_t, pod_name)

    if isJob:
        logging.info("count job_id %s"%service_name)
        job_pod_gauge.add_metric([service_name, pod_name, namespace, phase, host_ip,
                                  initialized, pod_scheduled, ready], 1)
        return
    else:
        pai_pod_gauge.add_metric([service_name, pod_name, namespace, phase, host_ip,
            initialized, pod_scheduled, ready], 1)

    # generate pai_containers
    if status.get("containerStatuses") is not None:
        container_statuses = status["containerStatuses"]

        for container_status in container_statuses:
            container_name = container_status["name"]

            ready = False

            if container_status.get("ready") is not None:
                ready = container_status["ready"]

            container_state = None
            if container_status.get("state") is not None:
                state = container_status["state"]
                if len(state) != 1:
                    error_counter.labels(type="unexpected_container_state").inc()
                    logger.error("unexpected state %s in container %s",
                            json.dumps(state), container_name)
                else:
                    container_state = list(state.keys())[0].lower()

            pai_container_gauge.add_metric([service_name, pod_name, container_name,
                namespace, container_state, host_ip, str(ready).lower()], 1)


def process_pods_status(pods_object, pai_pod_gauge, pai_container_gauge,
        pods_info, service_endpoints, vc_usage,job_pod_gauge):
    def _map_fn(item):
        return catch_exception(parse_pod_item,
                "catch exception when parsing pod item",
                None,
                item,
                pai_pod_gauge, pai_container_gauge,
                pods_info, service_endpoints, vc_usage,job_pod_gauge)

    list(map(_map_fn, pods_object["items"]))


def collect_healthz(gauge, histogram, scheme, address, port, url, ca_path, headers):
    with histogram.time():
        error = "ok"
        try:
            error = "heathy"
            #error = requests.get("{}://{}:{}{}".format(scheme, address, port, url), headers = headers, verify = ca_path).text
        except Exception as e:
            error_counter.labels(type="healthz").inc()
            error = str(e)
            logger.exception("requesting %s:%d%s failed", address, port, url)

        gauge.add_metric([error, address], 1)


def collect_k8s_component(api_server_scheme, api_server_ip, api_server_port, ca_path, headers):
    k8s_gauge = gen_k8s_api_gauge()

    collect_healthz(k8s_gauge, api_healthz_histogram,
            api_server_scheme, api_server_ip, api_server_port, "/healthz", ca_path, headers)

    return [k8s_gauge]


## we separate gpu and npu into different instances
## coz the cluster is heterogeneous, there are npus and gpus there
## and we need to monitor them respectively
def parse_node_item(node, 
        pai_node_gauge,

        gauge_node_device_avail,
        gauge_node_device_used,
        gauge_node_device_reserved,
        gauge_node_device_total,
        gauge_node_device_allocatable,

        pods_info, 
        cluster_gpu_info,
        cluster_npu_info
        ):

    ip = None
    addresses = walk_json_field_safe(node, "status", "addresses")
    logger.debug("calling parse_node_item")

    if addresses is not None:
        for addr in addresses:
            if addr.get("type") == "InternalIP":
                ip = addr.get("address")

    if ip is None:
        ip = node["metadata"]["name"]

    processor_resource_mark = ""
    device_capacity = 0
    device_allocatable = 0
    disk_pressure = memory_pressure = out_of_disk = ready = unschedulable = "unknown"
    deviceType = walk_json_field_safe(node, "metadata", "labels", "gpuType") or ""

    if node.get("status") is not None:
        status = node["status"]

        conditions = walk_json_field_safe(status, "conditions")
        if conditions is not None:
            for cond in conditions:
                cond_t = cond["type"]
                node_status = cond["status"].lower()

                if cond_t == "DiskPressure":
                    disk_pressure = node_status
                elif cond_t == "MemoryPressure":
                    memory_pressure = node_status
                elif cond_t == "OutOfDisk":
                    out_of_disk = node_status
                elif cond_t == "Ready":
                    ready = node_status
                else:
                    error_counter.labels(type="unknown_node_cond").inc()
                    logger.error("unexpected condition %s in node %s", cond_t, ip)
        else:
            pass


        # loop through mark list to find out what type the processor is
        for resource_mark in ResourceMark.resource_mark_list:
            if walk_json_field_safe(status, "capacity", resource_mark):
                processor_resource_mark = resource_mark
                break

            # https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/node-allocatable.md
            # [Allocatable] = [Node Capacity] - [Kube-Reserved] - [System-Reserved] - [Hard-Eviction-Threshold]
        device_capacity = int(walk_json_field_safe(status, "capacity", processor_resource_mark) or 0)
        device_allocatable = int(walk_json_field_safe(status, "allocatable", processor_resource_mark) or 0)
            
        if device_capacity > 0:
            if ResourceMark.is_gpu_resource(processor_resource_mark):
                #gauge_node_gpu_avail.add_metric([ip], device_capacity)
                cluster_gpu_info.capacity += device_capacity
                logger.debug("gpu data. ip[%s], total capacity found[%d], new capacity to add[%d], mark[%s]" %
                                ([ip], cluster_gpu_info.capacity, device_capacity, processor_resource_mark))

            elif ResourceMark.is_npu_resource(processor_resource_mark):
                #gauge_node_npu_avail.add_metric([ip], device_capacity)
                cluster_npu_info.capacity += device_capacity
                logger.debug("npu data. ip[%s], total capacity found[%d], new capacity to add[%d], mark[%s]" %
                                ([ip], cluster_npu_info.capacity, device_capacity, processor_resource_mark))
            else:
                pass
            
        # Because k8s api's node api do not record how much resource left for
        # allocation, so we have to compute it ourselves.
        # there must be only one type of processor within the node
        used_processor = 0         ## processors exclude preemptable ones
        total_used_processor = 0   ## processors include preemptable ones
        preemptable_processor = 0

        # compute npu/gpu resouces used by all pods
        # used_processor = sum(pod_info.used_processor)
        # available = total - used_processor
        logger.info(pods_info)
        if pods_info.get(ip) is not None:
            for pod in pods_info[ip]:

                if pod.resource_mark != processor_resource_mark:
                    continue
                else:
                    pass

                ## preemptable processor is considered as allocable resource?
                ## so it doesn't be part of used processors?
                if pod.preemptable:
                    preemptable_processor += pod.used_processor
                else:
                    used_processor += pod.used_processor

            total_used_processor += used_processor

        else:
            pass

        logger.info("used_processor[%d], preemptable_processor[%d]" % (used_processor, preemptable_processor))

        if walk_json_field_safe(node, "spec", "unschedulable") != True and ready == "true":

            available = max(0, device_allocatable - used_processor)
            preemptable_available = max(0, device_allocatable - used_processor - preemptable_processor)
            reserved = max(0,device_capacity-device_allocatable)

            gauge_node_device_total.add_metric([ip,deviceType,processor_resource_mark], device_capacity)
            gauge_node_device_avail.add_metric([ip,deviceType,processor_resource_mark], available)
            gauge_node_device_used.add_metric([ip,deviceType,processor_resource_mark], total_used_processor)
            gauge_node_device_reserved.add_metric([ip,deviceType,processor_resource_mark], reserved)
            gauge_node_device_allocatable.add_metric([ip,deviceType,processor_resource_mark], device_allocatable)

            # dispatch gpu/npu info to prometheus by node ip
            if ResourceMark.is_gpu_resource(processor_resource_mark):

                cluster_gpu_info.available += available
                cluster_gpu_info.preemptable_available += preemptable_available
                cluster_gpu_info.allocatable += device_allocatable
                cluster_gpu_info.reserved += reserved

                logger.debug("dispatch gauge info. found gpu: ip[%s], device_capacity[%d], preemptable_available[%d], device_allocatable[%d]" % 
                               (ip, device_capacity, preemptable_available, device_allocatable))

            elif ResourceMark.is_npu_resource(processor_resource_mark):

                cluster_npu_info.available += available
                cluster_npu_info.preemptable_available += preemptable_available
                cluster_npu_info.allocatable += device_allocatable
                cluster_npu_info.reserved += reserved

                logger.debug("dispatch gauge info. found npu: ip[%s], device_capacity[%d], available[%d], total_used_processor[%d]" % 
                                (ip, device_capacity, available, total_used_processor))

        else:
            ## this node is unschedulable

            gauge_node_device_total.add_metric([ip, deviceType,processor_resource_mark], 0)
            gauge_node_device_avail.add_metric([ip, deviceType,processor_resource_mark], 0)
            gauge_node_device_used.add_metric([ip, deviceType,processor_resource_mark], 0)
            gauge_node_device_reserved.add_metric([ip, deviceType,processor_resource_mark], 0)
            gauge_node_device_allocatable.add_metric([ip, deviceType, processor_resource_mark], 0)

            logger.debug("node is unschedulable. ip[%s]" % (ip))

    else:
        logger.warning("unexpected structure of node %s: %s", ip, json.dumps(node))

    unschedulable_s = walk_json_field_safe(node, "spec", "unschedulable")
    if unschedulable_s is True:
        unschedulable = "true"
    else:
        unschedulable = "false"

    pai_node_gauge.add_metric([ip, disk_pressure, memory_pressure, out_of_disk, ready, unschedulable,deviceType], 1)
    return

## pods_info
## dict{}
## key:   string, pod_ip
## value: list,   PodInfo
def process_nodes_status(nodes_object, pods_info, cluster_gpu_info, cluster_npu_info):
    
    logger.debug("calling process_nodes_status")
    pai_node_gauge = gen_pai_node_gauge()

    # all type of device
    gauge_node_device_avail = gen_gauge_node_device_available()
    gauge_node_device_used = gen_gauge_node_device_used()
    gauge_node_device_reserved = gen_gauge_node_device_reserved()
    gauge_node_device_total = gen_gauge_node_device_total()
    gauge_node_device_allocatable = gen_k8s_node_device_allocatable()

    def _map_fn(item):
        return catch_exception(parse_node_item,
                "catch exception when parsing node item",
                None,
                item,
                pai_node_gauge,

                gauge_node_device_avail,
                gauge_node_device_used,
                gauge_node_device_reserved,
                gauge_node_device_total,
                gauge_node_device_allocatable,

                pods_info,
                cluster_gpu_info,
                cluster_npu_info)

    list(map(_map_fn, nodes_object["items"]))

    return [pai_node_gauge,gauge_node_device_avail,gauge_node_device_used,gauge_node_device_reserved,gauge_node_device_total,gauge_node_device_allocatable]


def process_vc_quota(vc_object):
    result = {}

    for vc_info in vc_object["result"]:
        name = vc_info["vcName"]
        quota = json.loads(vc_info["quota"])
        result[name] = quota # quota is a map which key is gpu_type, value is int count

    return result


def query_vc_quota_info(vc_quota_url):
    if vc_quota_url is None:
        return {}

    vc_object = request_with_histogram(vc_quota_url, list_vc_quota_histogram,
            None, None)
    return process_vc_quota(vc_object)

def query_device_quota_info(device_quota_url):
    if device_quota_url is None:
        return {}

    vc_object = request_with_histogram(device_quota_url, list_vc_quota_histogram,
            None, None)
    return vc_object

class VcUsage(object):
    def __init__(self):
        # key is vc_name, value is a map with key to be gpu_type and value is an
        # array of two int.
        # The first is total used, the second is those non-preemptable used
        self.map = collections.defaultdict(lambda :
                collections.defaultdict(lambda : [0, 0]))

    def add_preemptable_used(self, vc, gpu_type, count):
        self.map[vc][gpu_type][0] += count

    def add_used(self, vc, gpu_type, count):
        self.map[vc][gpu_type][0] += count
        self.map[vc][gpu_type][1] += count

    def __repr__(self):
        return str(self.map)

# Let Qi to be quota admin set to each VC, and R to be unschedulable GPU in cluster,
# Ui to be used GPU in cluster and A to be available GPU in cluster, so to compute
# what real quota and available GPUs is for each VC is computed using following
# formula:
# Qi' = Qi - R * (Qi / sum(Qi))
# Qi'' = max(Qi' - Ui, 0)
# Ai = A * (Qi'' / sum(Qi''))
# To display:
# * total gpu: Qi
# * used gpu: Ui
# * available gpu: Ai
# * unschedulable gpu: Qi - Ui - Ai
def process_vc_info(vc_quota_url, device_type_quota_url,vc_usage, cluster_gpu_info,cluster_npu_info):
    try:
        vc_info = query_vc_quota_info(vc_quota_url)
        device_type_info = query_device_quota_info(device_type_quota_url)
        return gen_vc_metrics(vc_info, vc_usage, cluster_gpu_info,cluster_npu_info,device_type_info)
    except Exception as e:
        error_counter.labels(type="vc_quota_query").inc()
        logger.exception("failed to query vc info")
        return []

def gen_vc_metrics(vc_info, vc_usage, cluster_gpu_info,cluster_npu_info,device_type_info):
    logger.info("vc_info %s, vc_usage %s, cluster_gpu_info %s cluster_npu_info %s device_type_info %s",
            vc_info, vc_usage, cluster_gpu_info,cluster_npu_info,device_type_info)

    vc_total_gauge = gen_k8s_vc_device_total()
    vc_avail_gauge = gen_k8s_vc_device_available()
    vc_unschedulable_gauge = gen_k8s_vc_device_unschedulable()
    vc_preemptive_avail_gauge = gen_k8s_vc_device_preemptive_available()

    try:
        vc_quota_sum = collections.defaultdict(lambda : 0)

        for vc_name, gpu_info in vc_info.items():
            for gpu_type, total in gpu_info.items():
                if gpu_type not in device_type_info:
                    continue
                vc_total_gauge.add_metric([vc_name, device_type_info[gpu_type]["deviceStr"]], total)
                vc_quota_sum[device_type_info[gpu_type]["deviceStr"]] += total

        unallocatable={}
        unallocatable["nvidia.com/gpu"] = cluster_gpu_info.capacity - cluster_gpu_info.allocatable
        unallocatable["npu.huawei.com/NPU"] = cluster_npu_info.capacity - cluster_npu_info.allocatable

        # key is vc_name, value is a map with key to be gpu_type and value to be real
        # quota
        ratio = collections.defaultdict(lambda : {})

        for vc_name, gpu_info in vc_info.items():
            for gpu_type, quota in gpu_info.items():
                if gpu_type not in device_type_info:
                    continue
                if vc_quota_sum[device_type_info[gpu_type]["deviceStr"]] == 0:
                    vc_quota = 0
                else:
                    vc_quota = quota - int(math.ceil(unallocatable[device_type_info[gpu_type]["deviceStr"]] * quota / vc_quota_sum[device_type_info[gpu_type]["deviceStr"]]))
                used = vc_usage.map[vc_name][gpu_type][1]
                preemptive_used = vc_usage.map[vc_name][gpu_type][0]

                ratio[vc_name][gpu_type] = [max(vc_quota - preemptive_used, 0),max(vc_quota - used, 0)]

        ratio_sum = collections.defaultdict(lambda : [0,0])
        for vc_name, gpu_info in ratio.items():
            for gpu_type, cur_ratio in gpu_info.items():
                if gpu_type not in device_type_info:
                    continue
                deviceStr = device_type_info[gpu_type]["deviceStr"]
                ratio_sum[deviceStr] = list(map(add,ratio_sum[deviceStr],cur_ratio))

        ### if not all devices is allcated to vc,this make sense
        for deviceStr,resources_list in ratio_sum.items():
            if deviceStr == "nvidia.com/gpu":
                cluster_info = cluster_gpu_info
            else:
                cluster_info = cluster_npu_info
            if resources_list[1]<cluster_info.available:
                resources_list[1] = cluster_info.available
            if resources_list[0] < cluster_info.preemptable_available:
                resources_list[0] = cluster_info.preemptable_available

        for vc_name, gpu_info in ratio.items():
            for gpu_type, cur_ratio in gpu_info.items():
                if gpu_type not in device_type_info:
                    continue
                if vc_name not in vc_usage.map or gpu_type not in vc_usage.map[vc_name]:
                    deviceStr = device_type_info[gpu_type]["deviceStr"]
                    labels = [vc_name, deviceStr]
                    # no job running in this vc or using this gpu type
                    if all((x== 0 for x in ratio_sum[deviceStr])):
                        available = 0
                        preemptive_available=0
                    else:
                        if deviceStr == "npu.huawei.com/NPU":
                            available = int(math.floor(cluster_npu_info.available * cur_ratio[1] / ratio_sum[deviceStr][1]))
                            reserved = int(math.floor(cluster_npu_info.reserved * cur_ratio[1] / ratio_sum[deviceStr][1]))
                            preemptive_available = int(math.floor(cluster_npu_info.preemptable_available * cur_ratio[0] / ratio_sum[deviceStr][0]))
                        else:
                            available = int(math.floor(cluster_gpu_info.available * cur_ratio[1] / ratio_sum[deviceStr][1]))
                            reserved = int(math.floor(cluster_gpu_info.reserved * cur_ratio[1] / ratio_sum[deviceStr][1]))
                            preemptive_available = int(math.floor(cluster_gpu_info.preemptable_available * cur_ratio[0] / ratio_sum[deviceStr][0]))
                    quota = vc_info[vc_name][gpu_type]
                    vc_avail_gauge.add_metric(labels, available)
                    vc_preemptive_avail_gauge.add_metric(labels, preemptive_available)
                    vc_unschedulable_gauge.add_metric(labels, max(0, reserved))

        for vc_name, vc_usage_info in vc_usage.map.items():
            for gpu_type, vc_used in vc_usage_info.items():
                if gpu_type not in device_type_info:
                    continue
                if vc_name not in vc_info:
                    logger.warning("ignore used gpu in %s, but vc quota do not have this vc, possible due to job template error", vc_name)
                    continue

                if gpu_type not in vc_info[vc_name]:
                    logger.warning("ignore used gpu %s in %s, but vc quota do not have this gpu_type", gpu_type, vc_name)
                    continue
                deviceStr = device_type_info[gpu_type]["deviceStr"]
                labels = [vc_name, deviceStr]

                cur_ratio = ratio[vc_name][gpu_type]
                quota = vc_info[vc_name][gpu_type]
                if all((x== 0 for x in ratio_sum[deviceStr])):
                    available = 0
                    preemptive_available = 0
                    reserved = 0
                else:
                    if deviceStr == "npu.huawei.com/NPU":
                        available = int(math.floor(cluster_npu_info.available * cur_ratio[1] / ratio_sum[deviceStr][1]))
                        reserved = int(math.floor(cluster_npu_info.reserved * cur_ratio[1] / ratio_sum[deviceStr][1]))
                        preemptive_available = int(math.floor(cluster_npu_info.preemptable_available * cur_ratio[0] / ratio_sum[deviceStr][0])) if ratio_sum[deviceStr][0]!=0 else 0
                    else:
                        available = int(math.floor(cluster_gpu_info.available * cur_ratio[1] / ratio_sum[deviceStr][1]))
                        reserved = int(math.floor(cluster_gpu_info.reserved * cur_ratio[1] / ratio_sum[deviceStr][1]))
                        preemptive_available = int(math.floor(cluster_gpu_info.preemptable_available * cur_ratio[0] / ratio_sum[deviceStr][0])) if ratio_sum[deviceStr][0]!=0 else 0
                total_used, non_preemptable_used = vc_used
                vc_avail_gauge.add_metric(labels, available)
                vc_preemptive_avail_gauge.add_metric(labels, preemptive_available)
                vc_unschedulable_gauge.add_metric(labels, max(0, reserved))
    except Exception as e:
        error_counter.labels(type="vc_quota").inc()
        logger.exception("failed to process vc info")

    return [vc_total_gauge, vc_avail_gauge, vc_preemptive_avail_gauge,
            vc_unschedulable_gauge]


def process_pods(k8s_api_addr, ca_path, headers, pods_info, service_endpoints, vc_usage):
    list_pods_url = "{}/api/v1/pods".format(k8s_api_addr)

    pai_pod_gauge = gen_pai_pod_gauge()
    job_pod_gauge = gen_job_pod_gauge()
    pai_container_gauge = gen_pai_container_gauge()

    try:
        pods_object = get_pods_info(list_pods_histogram)
        process_pods_status(pods_object, pai_pod_gauge, pai_container_gauge, pods_info, service_endpoints, vc_usage,job_pod_gauge)

    except Exception as e:
        error_counter.labels(type="parse").inc()
        logger.exception("failed to process pods")

    return [pai_pod_gauge, pai_container_gauge,job_pod_gauge]


def process_nodes(k8s_api_addr, ca_path, headers, pods_info,
    cluster_gpu_info, cluster_npu_info):

    logger.debug("calling process_nodes")

    list_nodes_url = "{}/api/v1/nodes/".format(k8s_api_addr)
    nodes_object = get_nodes_info(list_nodes_histogram)

    return process_nodes_status(nodes_object, pods_info, cluster_gpu_info, cluster_npu_info)


def process_unscheduled_pods(pods_info, cluster_gpu_info):
    used_gpu = 0
    preemptable_used_gpu = 0
    unscheduled_pods = pods_info.get("unscheduled", [])
    for pod in unscheduled_pods:
        if pod.preemptable:
            preemptable_used_gpu += pod.gpu
        else:
            used_gpu += pod.gpu

    cluster_gpu_info.available -= used_gpu
    cluster_gpu_info.preemptable_available -= (used_gpu + preemptable_used_gpu)


def load_machine_list(configFilePath):
    with open(configFilePath, "r") as f:
        return yaml.load(f)["hosts"]

# Execute a ssh cmd
# Return the output of the remote command to local
def local_ssh_exec_cmd_with_output(cmd, supressWarning = False):

    if len(cmd)==0:
        return "";

    if supressWarning:
        cmd += " 2>/dev/null"

    execmd = cmd
    print(execmd)

    try:
        output = subprocess.check_output( execmd, shell=True).decode('utf-8')
    except subprocess.CalledProcessError as e:
        output = "Return code: " + str(e.returncode) + ", output: " + e.output.strip()

    #print output
    return output

def get_pods_info(histogram):

    pods = json.loads(local_ssh_exec_cmd_with_output("kubectl get pods --all-namespaces -o json"))

    if "apiVersion" in pods:
        logger.debug("get_pods_info succ. apiVersion: %s" % pods["apiVersion"])
    else:
        logger.error("get_pods_info fail. apiVersion not found. pods[%s]" % pods)

    return pods

def get_nodes_info(histogram):

    pods = json.loads(local_ssh_exec_cmd_with_output("kubectl get nodes -o json"))
    return pods

def request_with_histogram(url, histogram, ca_path, headers):
    with histogram.time():
        try:
            res = requests.get(url, headers=headers, verify=ca_path)
            return res.json()
        except Exception as e:
            logger.error(res.content)
            raise

def try_remove_old_prom_file(path):
    """ try to remove old prom file, since old prom file are exposed by node-exporter,
    if we do not remove, node-exporter will still expose old metrics """
    if os.path.isfile(path):
        try:
            os.unlink(path)
        except Exception as e:
            logger.warning("can not remove old prom file %s", path)

def register_stack_trace_dump():
    faulthandler.register(signal.SIGTRAP, all_threads=True, chain=False)

 # https://github.com/prometheus/client_python/issues/322#issuecomment-428189291
def burninate_gc_collector():
    for callback in gc.callbacks[:]:
        if callback.__qualname__.startswith("GCCollector."):
            gc.callbacks.remove(callback)

    for name, collector in list(prometheus_client.REGISTRY._names_to_collectors.items()):
        if name.startswith("python_gc_"):
            try:
                prometheus_client.REGISTRY.unregister(collector)
            except KeyError:  # probably gone already
                pass

class HealthResource(Resource):
    def render_GET(self, request):
        request.setHeader("Content-Type", "text/html; charset=utf-8")
        return "<html>Ok</html>".encode("utf-8")


def main(args):
    register_stack_trace_dump()
    burninate_gc_collector()

    log_dir = args.log
    try_remove_old_prom_file(log_dir + "/watchdog.prom")
    decay_time = datetime.timedelta(seconds=float(args.interval) * 2)

    services_ref = AtomicRef(decay_time)
    loop_result_ref = AtomicRef(decay_time)

    t = threading.Thread(target=loop, name="loop",
            args=(args, services_ref, loop_result_ref))
    t.daemon = True
    t.start()

    t = threading.Thread(target=requestor, name="requestor",
            args=(args, services_ref))
    t.daemon = True
    t.start()

    REGISTRY.register(CustomCollector([loop_result_ref]))

    root = Resource()
    root.putChild(b"metrics", MetricsResource())
    root.putChild(b"healthz", HealthResource())

    factory = Site(root)
    reactor.listenTCP(int(args.port), factory)
    reactor.run()


class ServiceEndpoint(object):
    def __init__(self, name, ip, port, path, timeout):
        self.name = name
        self.ip = ip
        self.port = port
        self.path = path
        self.timeout = timeout

    def __repr__(self):
        return "http://%s:%s/%s" % (self.ip, self.port, self.path)


def requestor(args, services_ref):
    while True:
        services = services_ref.get(datetime.datetime.now()) or ()

        logger.debug("get %d of services", len(services))

        result = []

        for s in services:
            url = urllib.parse.urljoin("http://{}:{}".format(s.ip, s.port),
                    s.path)
            try:
                with service_response_histogram.labels(s.name, s.ip).time():
                    resp = requests.get(url, timeout=s.timeout)
                code = str(resp.status_code)
            except Exception as e:
                logger.exception("requesting %s failed", url)
                code = str(e)

            service_response_counter.labels(s.name, s.ip, code).inc()

        # The minimal sleep time is 10s
        time.sleep(max(10, float(args.interval) / 3))


class ClusterGPUInfo(object):
    def __init__(self):
        self.capacity = 0
        self.available = 0
        self.preemptable_available = 0 # gpu available for preemptable job
        self.allocatable = 0
        self.reserved = 0

    def __repr__(self):
        return "capacity: %d, available: %d, preemptable_available %s, allocatable %d,reserved %d" % (
                self.capacity,
                self.available,
                self.preemptable_available,
                self.allocatable,
                self.reserved,
                )

class ClusterNPUInfo(object):
    def __init__(self):
        self.capacity = 0
        self.available = 0
        self.preemptable_available = 0 # npu available for preemptable job
        self.allocatable = 0
        self.reserved = 0

    def __repr__(self):
        return "capacity: %d, available: %d, preemptable_available %s, allocatable %d,reserved %d" % (
                self.capacity,
                self.available,
                self.preemptable_available,
                self.allocatable,
                self.reserved,
                )


def loop(args, services_ref, result_ref):
   
    logger.debug("calling loop")

    address = args.k8s_api
    parse_result = urllib.parse.urlparse(address)
    api_server_scheme = parse_result.scheme
    api_server_ip = parse_result.hostname
    api_server_port = parse_result.port or 80

    vc_quota_url = args.vc_url
    device_type_quota_url = args.device_type_url
    ca_path = args.ca
    bearer_path = args.bearer

    if (ca_path is None and bearer_path is not None) or (ca_path is not None and bearer_path is None):
        logger.warning("please provide bearer_path and ca_path at the same time or not")
    else:
        pass

    headers = None
    if not os.path.isfile(ca_path):
        ca_path = None
    else:
        pass

    if not os.path.isfile(bearer_path):
        bearer_path = None

    if bearer_path is not None:
        with open(bearer_path, 'r') as bearer_file:
           bearer = bearer_file.read()
           headers = {'Authorization': "Bearer {}".format(bearer)}

    while True:
        result = []

        try:
            logger.debug("going to update node status")
            pods_info = collections.defaultdict(lambda : [])

            service_endpoints = []
            vc_usage = VcUsage()

            result.extend(process_pods(address, ca_path, headers, pods_info,
                service_endpoints, vc_usage))

            services_ref.set(service_endpoints, datetime.datetime.now())

            cluster_gpu_info = ClusterGPUInfo()
            cluster_npu_info = ClusterNPUInfo()

            result.extend(process_nodes(address, ca_path, headers, pods_info, cluster_gpu_info, cluster_npu_info))
            result.extend(process_vc_info(vc_quota_url,device_type_quota_url, vc_usage, cluster_gpu_info,cluster_npu_info))
            result.extend(collect_k8s_component(api_server_scheme, api_server_ip, api_server_port, ca_path, headers))
        
        except Exception as e:
            error_counter.labels(type="unknown").inc()
            logger.exception("watchdog failed in one iteration")

        result_ref.set(result, datetime.datetime.now())
        time.sleep(float(args.interval))


def get_logging_level():

    mapping = {
            "DEBUG": logging.DEBUG,
            "INFO": logging.INFO,
            "WARNING": logging.WARNING
            }

    result = logging.INFO

    if os.environ.get("LOGGING_LEVEL") is not None:
        level = os.environ["LOGGING_LEVEL"]
        result = mapping.get(level.upper())

        if result is None:
            sys.stderr.write("unknown logging level " + level + ", default to INFO\n")
            result = logging.INFO

    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("k8s_api", help="kubernetes api uri eg. http://10.151.40.133:8080")
    parser.add_argument("--log", "-l", help="log dir to store log", default="/datastorage/prometheus")
    parser.add_argument("--interval", "-i", help="interval between two collection", default="30")
    parser.add_argument("--port", "-p", help="port to expose metrics", default="9101")
    parser.add_argument("--ca", "-c", help="ca file path")
    parser.add_argument("--bearer", "-b", help="bearer token file path")
    parser.add_argument("--vc_url", "-u", required=False, help="url to list vc quota",default="http://localhost:5000/apis/ListVCs?userName=Administrator")
    parser.add_argument("--device_type_url", "-dtu", required=False, help="url to list device type",default="http://localhost:5000/apis/GetAllDevice?userName=Administrator")
    args = parser.parse_args()

    logging.basicConfig(format="%(asctime)s - %(levelname)s - %(filename)s:%(lineno)s - %(message)s",
            level=get_logging_level())

    main(args)
