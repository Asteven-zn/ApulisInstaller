@Library('apulis-build@master') _

buildPlugin ( {
    repoName = 'InstallationYTung'
    dockerImages = [
        [
            'compileContainer': '',
            'preBuild':[],
            'imageName': 'apulistech/dlworkspace_a910-device-plugin',
            'directory': 'manifests/images/a910-device-plugin',
            'dockerfilePath': '',
            'arch': ['arm64']
        ],
        [
            'compileContainer': '',
            'preBuild':[],
            'imageName': 'apulistech/dlworkspace_gpu-reporter',
            'directory': 'manifests/images/gpu-reporter',
            'dockerfilePath': '',
            'arch': ['amd64', 'arm64']
        ],
        [
            'compileContainer': '',
            'sidecar': 'common/build-resources',
            'preBuild':[
                ['manifests/images/grafana','mkdir -p ./download/'],
                ['manifests/images/grafana','docker cp {SIDECAR}:/resources/grafana/grafana_6.7.4_{ARCH}.deb ./download/']
            ],
            'imageName': 'apulistech/dlworkspace_grafana',
            'directory': 'manifests/images/grafana',
            'dockerfilePath': '',
            'arch': ['amd64', 'arm64']
        ],
        [
            'compileContainer': '',
            'sidecar': 'common/build-resources',
            'preBuild':[
                ['manifests/images/grafana-zh','mkdir -p ./download/'],
                ['manifests/images/grafana-zh','docker cp {SIDECAR}:/resources/grafana/grafana_6.7.4_{ARCH}.deb ./download/']
            ],
            'imageName': 'apulistech/dlworkspace_grafana-zh',
            'directory': 'manifests/images/grafana-zh',
            'dockerfilePath': '',
            'arch': ['amd64', 'arm64']
        ],
        // [
        //     'compileContainer': '',
        //     'preBuild':[],
        //     'imageName': 'apulistech/dlworkspace_image-label',
        //     'directory': 'manifests/images/image-label',
        //     'dockerfilePath': '',
        //     'arch': ['amd64', 'arm64']
        // ],
        [
            'compileContainer': '',
            'preBuild':[],
            'imageName': 'apulistech/dlworkspace_init-container',
            'directory': 'manifests/images/init-container',
            'dockerfilePath': '',
            'arch': ['amd64', 'arm64']
        ],
        [
            'compileContainer': '',
            'preBuild':[],
            'imageName': 'apulistech/dlworkspace_nginx',
            'directory': 'manifests/images/nginx',
            'dockerfilePath': '',
            'arch': ['amd64', 'arm64']
        ],
        [
            'compileContainer': '',
            'preBuild':[],
            'imageName': 'apulistech/dlworkspace_openresty',
            'directory': 'manifests/images/openresty',
            'dockerfilePath': '',
            'arch': ['amd64', 'arm64']
        ],
        [
            'compileContainer': '',
            'preBuild':[],
            'imageName': 'apulistech/dlworkspace_visual-job',
            'directory': 'manifests/images/visual-job',
            'dockerfilePath': '',
            'arch': ['amd64', 'arm64']
        ],
        [
            'compileContainer': '',
            'preBuild':[],
            'imageName': 'apulistech/dlworkspace_watchdog',
            'directory': 'manifests/images/watchdog',
            'dockerfilePath': '',
            'arch': ['amd64', 'arm64']
        ]
    ]
})
