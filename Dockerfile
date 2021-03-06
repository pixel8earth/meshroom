ARG CUDA_TAG=9.2
ARG OS_TAG=7
FROM pixel8earth/avoptimized:latest as builder
LABEL maintainer="AliceVision Team alicevision-team@googlegroups.com"

# Execute with nvidia docker (https://github.com/nvidia/nvidia-docker/wiki/Installation-(version-2.0))
# docker run -it --runtime=nvidia meshroom

ENV MESHROOM_DEV=/opt/Meshroom \
    MESHROOM_BUILD=/tmp/Meshroom_build \
    MESHROOM_BUNDLE=/opt/Meshroom_bundle \
    QT_DIR=/opt/qt/5.13.0/gcc_64 \
    PATH="${PATH}:${MESHROOM_BUNDLE}"

# Workaround for qmlAlembic/qtAliceVision builds: fuse lib/lib64 folders
# RUN cp -rf ${AV_INSTALL}/lib/* ${AV_INSTALL}/lib64 && rm -rf ${AV_INSTALL}/lib && ln -s ${AV_INSTALL}/lib64 ${AV_INSTALL}/lib

# Install libs needed by Qt
RUN yum install -y \
        flex \
        fontconfig \
        freetype \
        glib2 \
        libICE \
        libX11 \
        libxcb \
        libXext \
        libXi \
        libXrender \
        libSM \
        libXt-devel \
        libGLU-devel \
        mesa-libOSMesa-devel \
        mesa-libGL-devel \
        mesa-libGLU-devel \
        xcb-util-keysyms \
        xcb-util-image

# Install Python3
RUN yum install -y centos-release-scl
RUN yum install -y rh-python36

COPY . "${MESHROOM_DEV}"

# Install Meshroom requirements and freeze bundle
RUN source scl_source enable rh-python36 && cd "${MESHROOM_DEV}" && pip install -r dev_requirements.txt -r requirements.txt && python setup.py install_exe -d "${MESHROOM_BUNDLE}" && \
    find ${MESHROOM_BUNDLE} -name "*Qt5Web*" -delete && \
    find ${MESHROOM_BUNDLE} -name "*Qt5Designer*" -delete && \
    rm -rf ${MESHROOM_BUNDLE}/lib/PySide2/typesystems/ ${MESHROOM_BUNDLE}/lib/PySide2/examples/ ${MESHROOM_BUNDLE}/lib/PySide2/include/ ${MESHROOM_BUNDLE}/lib/PySide2/Qt/translations/ ${MESHROOM_BUNDLE}/lib/PySide2/Qt/resources/ && \
    rm ${MESHROOM_BUNDLE}/lib/PySide2/QtWeb* && \
    rm ${MESHROOM_BUNDLE}/lib/PySide2/pyside2-lupdate ${MESHROOM_BUNDLE}/lib/PySide2/pyside2-rcc

# Install Qt (to build plugins)
WORKDIR /tmp/qt
# Qt version in specified in docker/qt-installer-noninteractive.qs
# RUN curl -LO http://download.qt.io/official_releases/online_installers/qt-unified-linux-x64-online.run && \
#     chmod u+x qt-unified-linux-x64-online.run && \
#     ./qt-unified-linux-x64-online.run --verbose --platform minimal --script "${MESHROOM_DEV}/docker/qt-installer-noninteractive.qs" && \
#     rm ./qt-unified-linux-x64-online.run

WORKDIR ${MESHROOM_BUILD}

# Build Meshroom plugins
# RUN cmake "${MESHROOM_DEV}" -DALICEVISION_ROOT="${AV_INSTALL}" -DQT_DIR="${QT_DIR}" -DCMAKE_INSTALL_PREFIX="${MESHROOM_BUNDLE}/qtPlugins"
# RUN make -j8 qtOIIO
# RUN make -j8 qmlAlembic
# RUN make -j8 qtAliceVision
# RUN make -j8 && cd /tmp && rm -rf ${MESHROOM_BUILD}

RUN mv "${AV_BUNDLE}" "${MESHROOM_BUNDLE}/aliceVision"
RUN rm -rf ${MESHROOM_BUNDLE}/aliceVision/share/doc ${MESHROOM_BUNDLE}/aliceVision/share/eigen3 ${MESHROOM_BUNDLE}/aliceVision/share/fonts ${MESHROOM_BUNDLE}/aliceVision/share/lemon ${MESHROOM_BUNDLE}/aliceVision/share/libraw ${MESHROOM_BUNDLE}/aliceVision/share/man/ aliceVision/share/pkgconfig

FROM nvidia/cuda:${CUDA_TAG}-base-centos${OS_TAG}

ENV MESHROOM_BUNDLE=/opt/Meshroom_bundle \
    PATH="${PATH}:${MESHROOM_BUNDLE}"

RUN yum install -y centos-release-scl
RUN yum install -y rh-python36
RUN source scl_source enable rh-python36

COPY --from=builder ${MESHROOM_BUNDLE} ${MESHROOM_BUNDLE}
ENV LD_LIBRARY_PATH=${MESHROOM_BUNDLE}/aliceVision/lib:$LD_LIBRARY_PATH