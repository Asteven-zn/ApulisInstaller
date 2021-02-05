import subprocess
from xml.dom import minidom
import os
import logging
import re

import utils

logger = logging.getLogger(__name__)

class NpuInfo(object):

    def __init__(self,npu_util, npu_mem_util, temperature):
        self.npu_util = npu_util
        self.npu_mem_util = npu_mem_util
        self.temperature = temperature  # None or float celsius

def parse_npu_number_smi_output(npu_number_smi_output):
    lines = npu_number_smi_output.split("\n\t")[1:]
    numbers = []
    for one_line in lines:
        NPU_ID,Chip_ID,Chip_Logic_ID,Chip_Name =  filter(lambda x:x!="" and x!="\n", re.split(r"[\s]{3,}", one_line))
        numbers.append(NPU_ID)

    return numbers

def parse_smi_xml_result(npu_smi_output):
    result = {}
    for one_npu_id,one_npu_result in npu_smi_output:
        h = one_npu_result.split("\n\t")
        npu_util = npu_mem_util = temperature = None
        for one_line in h:
            key, value = one_line.split(":")
            if "Aicore Usage Rate(%)"==key.strip():
                npu_util = value
            elif "Memory Usage Rate(%)"==key.strip():
                npu_mem_util = value
            elif "Temperature(C)" == key.strip():
                temperature = value
        if not npu_util or not npu_mem_util:
            continue
        result[str(one_npu_id)] = NpuInfo(npu_util,npu_mem_util,temperature)
    return result


def huawei_npu_smi(histogram, timeout):
    out = utils.exec_shell_cmd("command -v npu-smi")
    if "npu-smi" not in out.lower():
        return None
    else:
        pass

    try:
        device_list_file = "/var/log/npu/npu_smi/device_list"
        npu_number_smi_output = ""

        with open(device_list_file, "r") as f:
            npu_number_smi_output = f.read()
            f.close()

        npu_number = parse_npu_number_smi_output(npu_number_smi_output)
        npu_smi_output = []

        for one_npu_id in npu_number:

            device_file = "/var/log/npu/npu_smi/device" + str(one_npu_id)
            device_info_output = ""

            with open(device_file, "r") as f:
                device_info_output = f.read()
                f.close()

            npu_smi_output.append((one_npu_id,device_info_output))

        return parse_smi_xml_result(npu_smi_output)

    except subprocess.CalledProcessError as e:
        logger.exception("command '%s' return with error (code %d): %s", e.cmd, e.returncode, e.output)
        
    except subprocess.TimeoutExpired:
        logger.warning("nvidia-smi timeout")

    except Exception:
        logger.exception("exec nvidia-smi error")
