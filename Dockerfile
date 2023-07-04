FROM centos:8

ARG CLOUDHSM_SDK_VERSION=3.4.4-1
ARG VAULT_VERSION=1.11.2

# fix deprecated centos repo
RUN sed -i -e "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-* && \
    sed -i -e "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-*

RUN yum update -y
RUN yum install -y wget jq unzip openssh-server unzip expect

# Install CloudHSM RPM packages.
RUN wget -q https://s3.amazonaws.com/cloudhsmv2-software/CloudHsmClient/EL8/cloudhsm-client-$CLOUDHSM_SDK_VERSION.el8.x86_64.rpm
RUN wget -q https://s3.amazonaws.com/cloudhsmv2-software/CloudHsmClient/EL8/cloudhsm-client-pkcs11-$CLOUDHSM_SDK_VERSION.el8.x86_64.rpm
RUN wget -q https://s3.amazonaws.com/cloudhsmv2-software/CloudHsmClient/EL8/cloudhsm-client-jce-$CLOUDHSM_SDK_VERSION.el8.x86_64.rpm
RUN yum install -y ./cloudhsm-client-$CLOUDHSM_SDK_VERSION.el8.x86_64.rpm \
                   ./cloudhsm-client-pkcs11-$CLOUDHSM_SDK_VERSION.el8.x86_64.rpm \
                   ./cloudhsm-client-jce-$CLOUDHSM_SDK_VERSION.el8.x86_64.rpm

# Install vault
RUN wget -q https://releases.hashicorp.com/vault/$VAULT_VERSION/vault_${VAULT_VERSION}_linux_amd64.zip && \
    unzip vault_${VAULT_VERSION}_linux_amd64.zip && \
    mv vault /usr/local/bin/ && \
    rm vault_${VAULT_VERSION}_linux_amd64.zip

# Install aws cli
RUN wget -q https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
RUN unzip awscli-exe-linux-x86_64.zip
RUN ./aws/install
RUN aws --version

# Install awscli
RUN dnf install python3-pip

# Security patching
RUN yum -y update && yum -y clean all

# Cleanup.
RUN yum remove -y unzip && yum clean all
    
# Create yolt group and user.
RUN groupadd -g 1000 -r yolt && \
    useradd -u 100 -m -d /home/yolt --no-log-init -r -g yolt yolt

RUN cp -r /opt/cloudhsm/etc /opt/cloudhsm/etc_original
RUN mkdir -p /opt/cloudhsm/etc
COPY bin /opt/cloudhsm/bin
RUN chown root:yolt /opt/cloudhsm
COPY certs/AWS_CloudHSM_Root-G1.crt /opt/cloudhsm/data
COPY certs/liquid_security_certificate.crt /opt/cloudhsm/data
RUN chown -R yolt:yolt /opt/cloudhsm/data /opt/cloudhsm/run
RUN chmod 600 /opt/cloudhsm/etc_original/client.key
ENV PATH="${PATH}:/opt/cloudhsm/bin"

# SSH daemon config.
RUN mkdir /opt/ssh
COPY sshd_config /opt/ssh/sshd_config
RUN ssh-keygen -f /opt/ssh/ssh_host_rsa_key -N '' -t rsa
RUN ssh-keygen -f /opt/ssh/ssh_host_dsa_key -N '' -t dsa
RUN chown yolt:yolt -R /opt/ssh
EXPOSE 2222/tcp

USER yolt
ENTRYPOINT ["cloudhsm-client.sh"]

