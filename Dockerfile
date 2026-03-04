# R Shiny医学数据分析应用 Dockerfile
# 使用rocker/shiny基础镜像
FROM rocker/shiny:4.5.2

# 维护者信息
LABEL maintainer="AutoTFL Medical Data Analysis App"

# 设置环境变量
ENV DISABLE_AUTO_UPDATE=1
ENV R_LIBS_USER=/usr/local/lib/R/site-library
ENV PKGTYPE=source
ENV R_HOME=/usr/local/lib/R
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 安装 R 及所有常见编译依赖
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        r-base-dev \
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
    && ldconfig \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 创建应用目录
RUN mkdir -p /app

# 设置工作目录
WORKDIR /app

# 首先复制依赖管理文件以利用Docker缓存
COPY install_dependencies.R /app/install_dependencies.R
RUN apt-get update && apt-get install -y libv8-dev && rm -rf /var/lib/apt/lists/*
# 安装 R 包，使用严格模式 - 包含所有必需的依赖包
# 使用 R -e 命令并设置错误处理，确保任何一个包安装失败都会中断构建，使用清华源镜像
RUN R -e "options(warn=2, timeout=600); install.packages(c( \
    'shiny', 'shinydashboard', 'shinyjs', 'shinyBS', 'bslib', \
    'shinyWidgets', 'waiter', 'shinyalert', \
    'dplyr', 'readr', 'readxl', 'haven', 'purrr', 'stringr', \
    'vroom', 'memoise', 'ggplot2', 'plotly', 'DT', 'gt', \
    'patchwork', 'reactable', 'cowplot', 'gridExtra', 'scales', \
    'RColorBrewer', 'cards', 'gtsummary', 'tfrmt', 'forcats', \
    'tidyr', 'rlang', 'rtables', 'tern', 'survival', 'broom', \
    'survminer', 'corrplot', 'ggsci', 'colourpicker', 'digest' \
    ), repos='https://mirrors.tuna.tsinghua.edu.cn/CRAN/', dependencies=TRUE)"

# 现在复制应用的其余文件
COPY . /app/

# 设置权限
RUN chown -R shiny:shiny /app && chmod -R 755 /app

# 设置Shiny应用端口
EXPOSE 3838

# 使用run_app.R启动应用，这是项目推荐的方式
CMD ["R", "-e", "options(shiny.port=3838, shiny.host='0.0.0.0'); shiny::runApp('app.R', port=3838, host='0.0.0.0')"]