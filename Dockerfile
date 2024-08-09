FROM alpine:3.18

RUN echo 'hosts: files dns' >> /etc/nsswitch.conf

# Set the JMeter, InfluxDB and Grafana version as a build argument
ARG JMETER_VERSION=5.5
ARG INFLUXDB_VERSION=1.8.10
ARG GRAFANA_VERSION=9.2.3

# Set JMeter Home
ENV JMETER_HOME /jmeter/apache-jmeter-$JMETER_VERSION
ENV JMETER_LIB /jmeter/apache-jmeter-$JMETER_VERSION/lib

# Add JMeter to the Path
ENV PATH $JMETER_HOME/bin:$PATH

# Install necessary utilities, OpenJDK, NGINX, and dependencies
RUN apk update && \
    apk add --no-cache openjdk16-jdk wget unzip ca-certificates iputils tar gzip netcat-openbsd libc6-compat nginx

# Update CA certificates
RUN update-ca-certificates

# Download and extract JMeter
RUN wget -O /jmeter.tgz https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-$JMETER_VERSION.tgz && \
    mkdir /jmeter && \
    tar -xzf /jmeter.tgz -C /jmeter && \
    rm /jmeter.tgz

# Download and install InfluxDB
RUN set -ex && \
    mkdir ~/.gnupg; \
    echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf; \
    apk add --no-cache --virtual .build-deps wget gnupg tar && \
    for key in \
        9D539D90D3328DC7D6C8D3B9D8FF8E1F7DF8B07E ; \
    do \
        gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys "$key" ; \
    done && \
    wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz.asc && \
    wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz && \
    gpg --batch --verify influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz.asc influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz && \
    mkdir -p /usr/src && \
    tar -C /usr/src -xzf influxdb-${INFLUXDB_VERSION}-static_linux_amd64.tar.gz && \
    chmod +x /usr/src/influxdb-*/influx \
             /usr/src/influxdb-*/influx_inspect \
             /usr/src/influxdb-*/influx_stress \
             /usr/src/influxdb-*/influxd &&\
    mv /usr/src/influxdb-*/influx \
       /usr/src/influxdb-*/influx_inspect \
       /usr/src/influxdb-*/influx_stress  \
       /usr/src/influxdb-*/influxd \
       /usr/bin/ &&\
    gpgconf --kill all && \
    rm -rf *.tar.gz* /usr/src /root/.gnupg && \
    apk del .build-deps

# Install Grafana
RUN wget https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz && \
    tar -zxvf grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz && \
    mv grafana-${GRAFANA_VERSION} /usr/share/grafana && \
    ln -s /usr/share/grafana/bin/grafana-server /usr/sbin/grafana-server && \
    ln -s /usr/share/grafana/bin/grafana-cli /usr/sbin/grafana-cli && \
    mkdir -p /etc/grafana /var/lib/grafana /var/log/grafana && \
    rm grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz

# Configure NGINX
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d /etc/nginx/conf.d

# Add the JMeter Scripts and Test data file folder from local to container
COPY ./JMeterFiles JMeterFiles
# Add jmeter and user properties files
COPY ./property-files/*.properties ${JMETER_HOME}/bin

# Copy InfluxDB configuration file
COPY ./influxDB/influxdb.conf /etc/influxdb/influxdb.conf

# Copy Grafana provisioning files
COPY ./grafana/provisioning /usr/share/grafana/conf/provisioning
COPY ./grafana/custom.ini /etc/grafana/grafana.ini

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Copy the init script
COPY init-influxdb.sh /init-influxdb.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh /init-influxdb.sh

# Expose ports for InfluxDB, Grafana, and NGINX
EXPOSE 80

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]