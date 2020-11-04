import json

with open('config/install_config.json') as f:
    data = json.load(f)
    with open('output.cfg','w') as fout:
        for key, value in data.items():
            if key != "worker_nodes" and key != "extra_master_nodes" and key != "storage" and "_comment" not in key:
                fout.write(key)
                fout.write("=")
                value_str="{}\n".format(value)
                fout.write(value_str)

        fout.write("worker_nodes=(\n")
        for worker_node_info in data["worker_nodes"]:
            fout.write(worker_node_info["host"] + "\n")
        fout.write(")\n")

        fout.write("worker_nodes_gpuType=(\n")
        for worker_node_info in data["worker_nodes"]:
            fout.write(worker_node_info["gpuType"] + "\n")
        fout.write(")\n")

        fout.write("worker_nodes_vendor=(\n")
        for worker_node_info in data["worker_nodes"]:
            fout.write(worker_node_info["vendor"] + "\n")
        fout.write(")\n")

        fout.write("extra_master_nodes=(\n")
        for extra_master_nodes_info in data["extra_master_nodes"]:
            fout.write(extra_master_nodes_info["host"] + "\n")
        fout.write(")\n")

        fout.write("storage_type=")
        fout.write(data["storage"]["type"] + "\n")
        fout.write("DLTS_STORAGE_PATH=")
        fout.write("\"")
        fout.write(data["storage"]["path"])
        fout.write("\"" + "\n")

        if "mountcmd" in data["storage"]:
            fout.write("storage_mount_cmd=")
            fout.write("\"")
            fout.write(data["storage"]["mountcmd"] + "\n")
            fout.write("\"" + "\n")
        else:
            fout.write("storage_mount_cmd=")
            fout.write("\"")
            fout.write("\"" + "\n")