FROM php:8.2.1-fpm

LABEL org.opencontainers.image.source=https://github.com/Netronaut/php-fpm-v8js/
LABEL org.opencontainers.image.description="PHP image containing the V8JS extension."
LABEL org.opencontainers.image.licenses="PHP-3.01"

# Compile V8 5.6 and newer (using GN)

# Install required dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    python \
    libglib2.0-dev \
    && rm -rf /var/lib/apt/lists/* \
    && cd /tmp \
    # Install depot_tools first (needed for source checkout)
    && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
    && export PATH=`pwd`/depot_tools:"$PATH" \
    # Download v8
    && fetch v8 \
    && cd v8 \
    # (optional) If you'd like to build a certain version:
    && git checkout 11.1.155 \
    && gclient sync \
    # Setup GN
    && tools/dev/v8gen.py -vv x64.release -- is_component_build=true use_custom_libcxx=false \
    # Build
    && ninja -C out.gn/x64.release/ \
    # Install to /opt/v8/
    && mkdir -p /opt/v8/{lib,include} \
    && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin \
      out.gn/x64.release/icudtl.dat /opt/v8/lib/ \
    && cp -R include/* /opt/v8/include/ \
    && apt-get install patchelf \
    && for A in /opt/v8/lib/*.so; do patchelf --set-rpath '$ORIGIN' $A; done

# Compile php-v8js itself
RUN cd /tmp \
    && git clone https://github.com/phpv8/v8js.git \
    && cd v8js \
    && phpize \
    && ./configure --with-v8js=/opt/v8/ LDFLAGS="-lstdc++" CPPFLAGS="-DV8_COMPRESS_POINTERS" \
    && make \
    && make test \
    && make install
