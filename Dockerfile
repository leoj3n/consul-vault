FROM alpine:3.6

RUN apk --no-cache add curl bash ca-certificates

ENV CONTAINERPILOT_VER=3.6.0
ENV CONTAINERPILOT=/etc/containerpilot.json5
RUN export CONTAINERPILOT_CHECKSUM=1248784ff475e6fda69ebf7a2136adbfb902f74b \
    && curl -Lso /tmp/containerpilot.tar.gz \
         "https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VER}/containerpilot-${CONTAINERPILOT_VER}.tar.gz" \
    && echo "${CONTAINERPILOT_CHECKSUM}  /tmp/containerpilot.tar.gz" | sha1sum -c \
    && tar zxf /tmp/containerpilot.tar.gz -C /usr/local/bin \
    && rm /tmp/containerpilot.tar.gz

ENV CONSUL_VERSION=1.5.1
RUN export CONSUL_CHECKSUM=58fbf392965b629db0d08984ec2bd43a5cb4c7cc7ba059f2494ec37c32fdcb91 \
    && export archive=consul_${CONSUL_VERSION}_linux_amd64.zip \
    && curl -Lso /tmp/${archive} https://releases.hashicorp.com/consul/${CONSUL_VERSION}/${archive} \
    && echo "${CONSUL_CHECKSUM}  /tmp/${archive}" | sha256sum -c \
    && cd /bin \
    && unzip /tmp/${archive} \
    && chmod +x /bin/consul \
    && rm /tmp/${archive}

ENV VAULT_VERSION=1.1.3
RUN export VAULT_CHECKSUM=293b88f4d31f6bcdcc8b508eccb7b856a0423270adebfa0f52f04144c5a22ae0 \
  && export archive=vault_${VAULT_VERSION}_linux_amd64.zip \
  && curl -Lso /tmp/${archive} https://releases.hashicorp.com/vault/${VAULT_VERSION}/${archive} \
  && echo "${VAULT_CHECKSUM}  /tmp/${archive}" | sha256sum -c \
  && cd /bin \
  && unzip /tmp/${archive} \
  && chmod +x /bin/vault \
  && rm /tmp/${archive}

COPY --chown=755 ./etc/vault.hcl /etc/
COPY --chown=755 ./etc/consul.hcl /etc/consul/
COPY --chown=755 ./etc/containerpilot.json5 /etc/
COPY --chown=755 ./bin/ /usr/local/bin/

# Put Consul data on a separate volume (via etc/consul.hcl) to avoid filesystem
# performance issues with Docker image layers. Not necessary on Triton, but...
VOLUME ["/data"]

# We don't need to expose these ports in order for other containers on Triton
# to reach this container in the default networking environment, but if we
# leave this here then we get the ports as well-known environment variables for
# purposes of linking.
EXPOSE 8200 8300 8301 8301/udp 8302 8302/udp 8400 8500 53 53/udp

#ENV GOMAXPROCS 2
ENV SHELL /bin/bash

ENTRYPOINT ["containerpilot"]
