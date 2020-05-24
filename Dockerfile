FROM fedora:31

LABEL maintainer="nuno.fonseca at gmail.com"

RUN dnf update -y && dnf install -y bzip2-devel  bzip2 zlib-devel git gcc wget R curl tar  && dnf clean all
ADD exe ./exe/
ADD R ./R/
ADD tests ./tests/
COPY install.sh .
RUN echo '#!/usr/bin/env bash' > /usr/bin/metabinkit_env
RUN echo 'source /opt/metabinkit_env.sh' >> /usr/bin/metabinkit_env
RUN echo 'bash' >> /usr/bin/metabinkit_env
RUN chmod u+x /usr/bin/metabinkit_env
RUN chmod a+x install.sh
RUN ./install.sh -i /opt && rm -rf tests
ENTRYPOINT ["/usr/bin/metabinkit_env"]
