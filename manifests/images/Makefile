NAME_PREFIX := apulistech
PROJECT_NAME := $(or $(PROJECT_NAME), library)
HARBOR := $(or $(HARBOR_SRV), harbor.sigsus.cn:8443)
VERSION := $(or $(IMAGE_VERSION), latest)

BUILD_ARCH := amd64
ifeq ($(uname -m),aarch64)
	BUILD_ARCH := arm64
endif

simple := a910-device-plugin gpu-reporter grafana grafana-zh image-label init-container \
	nginx openresty restfulapi2 visual-job watchdog webui3
push-simple := $(addprefix push-,$(simple))
cross-simple := $(addprefix cross-,$(simple))

.PHONY: build-native push-cross push-native $(push-simple) $(simple) $(cross-simple)

push-cross: $(cross-simple)
build-native: $(simple)
push-native: $(push-simple)

$(simple):
	docker build -t ${HARBOR}/${PROJECT_NAME}/${NAME_PREFIX}/$@-${BUILD_ARCH}:${VERSION} $@
	docker manifest create ${HARBOR}/${PROJECT_NAME}/${NAME_PREFIX}/$@:${VERSION} \
		${HARBOR}/${PROJECT_NAME}/${NAME_PREFIX}/$@-${BUILD_ARCH}:${VERSION} | \
	docker manifest create ${HARBOR}/${PROJECT_NAME}/${NAME_PREFIX}/$@:${VERSION} \
		${HARBOR}/${PROJECT_NAME}/${NAME_PREFIX}/$@-${BUILD_ARCH}:${VERSION} -a
	docker manifest annotate ${HARBOR}/${PROJECT_NAME}/${NAME_PREFIX}/$@:${VERSION} \
		${HARBOR}/${PROJECT_NAME}/${NAME_PREFIX}/$@-${BUILD_ARCH}:${VERSION} --os linux --arch ${BUILD_ARCH}

$(push-simple):
	docker manifest push ${HARBOR}/${PROJECT_NAME}/${NAME_PREFIX}/$(subst push-,,$@):${VERSION}

$(cross-simple):
	docker buildx build --platform linux/amd64 \
		-t ${HARBOR}/${PROJECT_NAME}/${NAME_PREFIX}/$(subst cross-,,$@):${VERSION} $(subst cross-,,$@) --push

