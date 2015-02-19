
ifeq ($(TARGET),rhel7)
	OS := rhel7
else
	OS := centos7
endif

ifeq ($(VERSION), 5.5)
	VERSION := 5.5
else
	VERSION :=
endif

.PHONY: build
build:
	hack/build.sh $(OS) $(VERSION)

