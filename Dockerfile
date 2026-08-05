# syntax=docker/dockerfile:1
# R Shiny医学数据分析应用 Dockerfile
# 使用rocker/shiny基础镜像
FROM rocker/shiny:4.5.3

# 维护者信息
LABEL maintainer="AutoTFL Medical Data Analysis App"

# 设置环境变量
ENV DISABLE_AUTO_UPDATE=1
ENV R_LIBS_USER=/usr/local/lib/R/site-library
ENV R_HOME=/usr/local/lib/R
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 预装 pak 包管理器（install_dependencies.R 使用它调用 PPM 二进制仓库）
RUN /usr/local/bin/R -e 'install.packages("pak", repos = "https://mirrors.tuna.tsinghua.edu.cn/CRAN/")'

# 切换 Ubuntu 清华镜像源（国内网络环境加速）
# 注意：必须使用 HTTPS，HTTP 会被拦截并返回 HTML 页面，apt 报 "Clearsigned file isn't valid (NOSPLIT)"
RUN sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources && \
    sed -i 's|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources

# 安装系统编译依赖；R 版本只使用 rocker/shiny 自带的 /usr/local/bin/R
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        g++ \
        gcc \
        gfortran \
        make \
        pkg-config \
        \
        libcurl4-openssl-dev \
        libssl-dev \
        libssh2-1-dev \
        libgit2-dev \
        libmbedtls-dev \
        \
        libxml2-dev \
        libicu-dev \
        libutf8proc-dev \
        \
        libfreetype-dev \
        libfontconfig-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libpng-dev \
        libjpeg-dev \
        libtiff-dev \
        \
        libudunits2-dev \
        libproj-dev \
        libgeos-dev \
        gdal-bin \
        libgdal-dev \
        \
        cmake \
        patch \
        xz-utils \
        autoconf \
        automake \
        libtool \
        zlib1g-dev \
        libbz2-dev \
        liblzma-dev \
        \
        libprotobuf-dev \
        protobuf-compiler \
        \
        libpq-dev \
        unixodbc-dev \
        libgmp-dev \
        libglpk-dev \
        libsodium-dev \
        libxt-dev \
        libmagick++-dev \
        libarchive-dev \
        libv8-dev \
        fonts-noto-cjk \
        fonts-wqy-zenhei \
        fonts-liberation \
    && fc-cache -fv \
    && ldconfig \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建应用目录
RUN mkdir -p /app

# 设置工作目录
WORKDIR /app

# 1. 优先复制本地包目录和依赖脚本，利用 Docker 缓存层
COPY package /app/package
COPY config /app/config
COPY install_dependencies.R /app/install_dependencies.R
COPY download_binary_packages.R /app/download_binary_packages.R

# 2. 执行依赖安装：pak 统一处理本地二进制包 + 在线 PPM 仓库
# install_dependencies.R 内部已实现该逻辑
RUN --mount=type=cache,target=/var/cache/r-site-library,sharing=locked \
    --mount=type=cache,target=/var/cache/r-pkg-downloads,sharing=locked \
    echo "==> Restoring cached R packages from previous build..." && \
    if [ -d /var/cache/r-site-library ] && \
       [ "$(ls -A /var/cache/r-site-library 2>/dev/null)" ]; then \
        cp -rn /var/cache/r-site-library/* /usr/local/lib/R/site-library/ 2>/dev/null || true; \
        echo "     Restored $(ls /var/cache/r-site-library 2>/dev/null | wc -l) packages from cache."; \
    fi && \
    echo "==> Restoring pak download cache..." && \
    mkdir -p /root/.cache/R/pkgcache && \
    if [ -d /var/cache/r-pkg-downloads ] && \
       [ "$(ls -A /var/cache/r-pkg-downloads 2>/dev/null)" ]; then \
        cp -rn /var/cache/r-pkg-downloads/* /root/.cache/R/pkgcache/ 2>/dev/null || true; \
    fi && \
    echo "==> Running R dependency installation..." && \
    /usr/local/bin/Rscript /app/install_dependencies.R && \
    echo "==> Saving installed R packages to build cache..." && \
    mkdir -p /var/cache/r-site-library && \
    cp -rn /usr/local/lib/R/site-library/* /var/cache/r-site-library/ && \
    echo "==> Saving pak download cache..." && \
    mkdir -p /var/cache/r-pkg-downloads && \
    if [ -d /root/.cache/R/pkgcache ]; then \
        cp -rn /root/.cache/R/pkgcache/* /var/cache/r-pkg-downloads/ 2>/dev/null || true; \
    fi && \
    echo "==> R package installation complete."

# 3. 复制剩余应用文件
COPY . /app/

# 设置权限
RUN chown -R shiny:shiny /app && chmod -R 755 /app

# 设置Shiny应用端口
EXPOSE 3838

# 使用run_app.R启动应用，这是项目推荐的方式
CMD ["/usr/local/bin/R", "-e", "options(shiny.port=3838, shiny.host='0.0.0.0', shiny.maxRequestSize=100*1024^2); shiny::runApp('app.R', port=3838, host='0.0.0.0')"]
