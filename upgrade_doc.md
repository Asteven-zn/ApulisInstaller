# 升级步骤

* 以下升级步骤仅针对目前(2020/08)，镜像版本号无修改的场景

## 1. 安装盘制作与镜像准备(update install pan)
* 检查`install_pan.sh/setImageList()`函数的镜像列表，如有新增/修改请在此处更新。
* 参照`install_pan.sh/setImageList()`函数的镜像列表，确保镜像推送到harbor制定位置。
* 使用`install_pan`制作安装盘，指定`-r`参数为harbor项目名称，如sz_gongdianju或sz_airs。
* 安装后，执行`ls -la`检查镜像文件夹里镜像，确保大小正常。如有大小为0的，请去harbor检查对应镜像是否存在。

## 2. 停止服务(stop services)
* 执行`tools/stop_services.sh`，停止所有DLWS service。
* 确保所有平台服务都停止。

## 3. 更新镜像至私有化部署集群harbor(update images)
* 首先需要确保除library和当前harbor项目的tag被删除。如当前项目为`sz_airs`，请确保`sz_gongdianju`全部删除。可使用`clear_harbor_project_imgs.sh`
* 执行`tools/load_docker_images.sh`，将新镜像文件夹中的镜像全部load。
* 执行`tools/push_image_to_harbor.sh`，将master01相关镜像推送到harbor。

## 4. 使用新DLWS代码覆盖旧代码(update dlws code)
```sh
tar -xvf ./YTung.tar.gz -C /home/dlwsadmin/DLWorkspace
```

## 5. 重启服务(start services)
* 执行`tools/start_service.sh`，启动所有DLWS service。
