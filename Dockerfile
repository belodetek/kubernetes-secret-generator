FROM debian AS artefact

ARG TARGETPLATFORM

COPY . .

RUN apt update && apt install -y git gnupg2 zstd file \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 23F3D4EA75716059 \
	&& echo "deb [arch=$(dpkg --print-architecture)] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
	&& apt update && apt install gh -y

RUN --mount=type=secret,id=GITHUB_TOKEN set -ax; \
    gh auth login --with-token </run/secrets/GITHUB_TOKEN && gh auth status \
    && release_sha=$(cd src; git rev-parse HEAD) \
    && asset=kubernetes-secret-generator-${release_sha}-$(echo ${TARGETPLATFORM} | sed 's#/#-#g') \
    && while ! gh run download --name ${asset}; do sleep $(((RAND%5)+1)); done \
	&& zstdcat kubernetes-secret-generator.zst > kubernetes-secret-generator \
	&& chmod +x kubernetes-secret-generator \
	&& file kubernetes-secret-generator


# --- runtime
FROM registry.access.redhat.com/ubi8/ubi-minimal:8.8

ENV OPERATOR=/usr/local/bin/kubernetes-secret-generator \
    USER_UID=1001 \
    USER_NAME=kubernetes-secret-generator

COPY --from=artefact kubernetes-secret-generator ${OPERATOR}
COPY src/build/bin /usr/local/bin
RUN /usr/local/bin/user_setup

ENTRYPOINT ["/usr/local/bin/entrypoint"]

USER ${USER_UID}
