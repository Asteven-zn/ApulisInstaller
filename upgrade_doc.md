# 升级步骤

* 以下升级步骤仅针对目前，镜像版本号无修改的场景

## 1. 安装盘制作与镜像准备
* 检查`install_pan.sh/setImageList()`函数的镜像列表，如有新增/修改请在此处更新。
* 参照`install_pan.sh/setImageList()`函数的镜像列表，确保镜像推送到harbor制定位置。
* 使用`install_pan`制作安装盘，指定`-r`参数为harbor项目名称，如sz_gongdianju或sz_airs。
* 安装后，执行`ls -la`检查镜像文件夹里镜像，确保大小正常。如有大小为0的，请去harbor检查对应镜像是否存在。


## 2. 更新镜像至私有化部署集群harbor
* 执行`tools/load_docker_images.sh`，将新镜像文件夹中的镜像全部load。
* 执行`tools/push_image_to_harbor.sh`，将master01相关镜像推送到harbor。

## 3. 使用新DLWS代码覆盖旧代码
```sh
tar -xvf ./YTung.tar.gz -C /home/dlwsadmin/DLWorkspace
```

## 4. 停止相关服务并重启
* 执行`tools/stop_services.sh`，停止所有DLWS service。
* 确保所有平台服务都停止。
* 执行`tools/start_service.sh`，启动所有DLWS service。
