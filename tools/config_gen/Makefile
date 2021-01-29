.PHONY: all build gotool clean

BINARY="config_gen"

all: gotool build

build:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ${BINARY}_amd64
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o ${BINARY}_arm64

gotool:
	go fmt ./
	go vet ./

clean:
	@if [ -f ${BINARY}_amd64 ] ; then rm ${BINARY}_amd64 ; fi
	@if [ -f ${BINARY}_arm64 ] ; then rm ${BINARY}_arm64 ; fi
