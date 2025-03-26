# Copyright (c) 2025 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

# use rhel9/ for Brew, not ubi9/
# can pin to specific tag filter using rhel8/go-toolset#^1.17
# https://registry.access.redhat.com/ubi9/go-toolset
FROM registry.redhat.io/ubi9/go-toolset:9.5-1742890357 as go-builder

USER root

COPY $REMOTE_SOURCES $REMOTE_SOURCES_DIR

RUN \
    ########################################################################
    # Build all Golang projects fetched from Cachito
    ########################################################################
    dnf -y -q install golang make gzip which openshift-clients && \
    # BEGIN Kubedock
    cd $REMOTE_SOURCES_DIR/kubedock/app && \
    # build kubedock application with dependencies resolved by Cachito
    source $REMOTE_SOURCES_DIR/kubedock/cachito.env && \
    LDFLAGS="-X github.com/joyrex2001/kubedock/internal/config.Date=`date -u +%Y%m%d-%H%M%S`  \
     -X github.com/joyrex2001/kubedock/internal/config.Build=9d21955b52e4905d916d24e724dcad195aef3515   \
     -X github.com/joyrex2001/kubedock/internal/config.Version=0.11.0  \
     -X github.com/joyrex2001/kubedock/internal/config.Image=joyrex2001/kubedock:0.11.0" && \
    CGO_ENABLED=0 go build -ldflags "${LDFLAGS}" -o kubedock && \
    chmod +x ./kubedock && \
    ./kubedock version && \
    # END Kubedock

    # BEGIN stow
    dnf -y -q install perl texinfo texinfo-tex git && \
    cd $REMOTE_SOURCES_DIR/stow/app && \
    mkdir -p $REMOTE_SOURCES_DIR/stow/app/build && \
    autoreconf -iv && \
    ./configure --prefix=$REMOTE_SOURCES_DIR/stow/app/build && \
    make install && \
    cd $REMOTE_SOURCES_DIR/stow/app/build/bin/ && \
    ./stow --version
    # END stow

# https://registry.access.redhat.com/ubi9-minimal
FROM registry.redhat.io/ubi9-minimal:9.5-1742914212

USER root

ENV \
    # We install everything to /home/tooling/ as /home/user/ may get overwritten, see github.com/eclipse/che/issues/22412
    HOME=/home/tooling \
    PATH="/home/user/.local/bin:/usr/bin:/home/user/go/bin:/home/tooling/.local/bin:${PATH:-/bin:/usr/bin}" \
    PKG_CONFIG_PATH="/usr/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}" \
    KUBECONFIG=/home/user/.kube/config \
    PROFILE_EXT=/etc/profile.d/udi_environment.sh \
    # Rootless podman install #1:
    # Set up environment variables to note that this is
    # not starting with usernamespace and default to
    # isolate the filesystem with chroot.
    _BUILDAH_STARTED_IN_USERNS="" BUILDAH_ISOLATION=chroot \
    SUMMARY="Red Hat OpenShift Dev Spaces - Universal Developer Image Base container" \
    DESCRIPTION="Red Hat OpenShift Dev Spaces - Universal Developer Image Base container" \
    PRODNAME="devspaces" \
    COMPNAME="udi-rhel9"

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="$DESCRIPTION" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME-container" \
      name="$PRODNAME/$COMPNAME" \
      version="3.20" \
      license="EPLv2" \
      maintainer="David Kwon <dakwon@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""

RUN mkdir -p /home/tooling/
ADD etc/storage.conf $HOME/.config/containers/storage.conf
ADD etc/entrypoint.sh /entrypoint.sh
COPY $REMOTE_SOURCES $REMOTE_SOURCES_DIR
COPY --chown=0:0 etc/podman-wrapper.sh /usr/bin/
RUN mkdir -p /home/tooling/
COPY --chown=0:0 etc/.stow-local-ignore /home/tooling/

# NOTE: uncomment for local build. Must also set full registry path in FROM to registry.redhat.io or registry.access.redhat.com
# enable rhel 9 content sets (from Brew) to resolve buildah
# COPY content_set*.repo /etc/yum.repos.d/

########################################################################
# Common Installations and Configuration
########################################################################

# COPY install.sh ./
# RUN chmod +x install.sh && ./install.sh

RUN microdnf install -y dnf && \
    # Disable codeready-builder repos to prevent accidentally installing incorrect packages
    dnf -y -q install 'dnf-command(config-manager)' && \
    # install libatomic_ops from codeready-builder before disabling it
    dnf -y -q install libatomic_ops && \
    dnf config-manager --set-disabled codeready-*

RUN dnf -y -q install --setopt=tsflags=nodocs \
        container-tools fuse-overlayfs \
        git ca-certificates jq \
        bash bash-completion tar gzip unzip bzip2 which shadow-utils findutils wget sudo git-lfs procps-ng tree vim && \
    dnf -y -q reinstall shadow-utils && \
    # fetch CVE updates (can exclude rpms to prevent update, eg., --exclude=odo)
    dnf -y -q update && \
    dnf -y -q clean all --enablerepo='*' && \
    dnf -y -q clean all && rm -rf /var/cache/yum && \
    mkdir -p /opt && \
    # add user and configure it
    useradd -u 1000 -G wheel,root -d /home/user --shell /bin/bash -m user && \
    # Bash-related files are backed up to /home/tooling/ in case they are deleted when persistUserHome is enabled.
    cp /home/user/.bashrc /home/tooling/.bashrc && \
    cp /home/user/.bash_profile /home/tooling/.bash_profile && \
    # $PROFILE_EXT contains all additions made to the bash environment
    touch ${PROFILE_EXT} && \
    # Setup $PS1 for a consistent and reasonable prompt
    touch /etc/profile.d/udi_prompt.sh && \
    echo "export PS1='\W \`git branch --show-current 2>/dev/null | sed -r -e \"s@^(.+)@\(\1\) @\"\`$ '" >> /etc/profile.d/udi_prompt.sh && \
    # Change permissions to let any arbitrary user
    mkdir -p /projects && \
    for f in "${HOME}" "/etc/passwd" "/etc/group" "/projects"; do \
        echo "Changing permissions on ${f}" && chgrp -R 0 ${f} && \
        chmod -R g+rwX ${f}; \
    done && \
    # Generate passwd.template
    cat /etc/passwd | \
    sed s#user:x.*#user:x:\${USER_ID}:\${GROUP_ID}::\${HOME}:/bin/bash#g \
    > ${HOME}/passwd.template && \
    cat /etc/group | \
    sed s#root:x:0:#root:x:0:0,\${USER_ID}:#g \
    > ${HOME}/group.template && \
    # Define user directory for binaries
    mkdir -p /home/tooling/.local/bin

RUN \
    ## Rootless podman install #2: install podman buildah skopeo e2fsprogs (above)
    ## Rootless podman install #3: tweaks to make rootless buildah work
    touch /etc/subgid /etc/subuid  && \
    chmod g=u /etc/subgid /etc/subuid /etc/passwd  && \
    echo user:10000:65536 > /etc/subuid  && \
    echo user:10000:65536 > /etc/subgid && \
    ## Rootless podman install #4: adjust storage.conf to enable Fuse storage.
    sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' /etc/containers/storage.conf && \
    mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers; \
    touch /var/lib/shared/overlay-images/images.lock; \
    touch /var/lib/shared/overlay-layers/layers.lock && \
    ## Rootless podman install #5: rename podman to allow the execution of 'podman run' using
    ##                             kubedock but 'podman build' using podman.orig
    mv /usr/bin/podman /usr/bin/podman.orig && \
    # Docker alias
    echo 'alias docker=podman' >> ${PROFILE_EXT}

# see container.yaml
COPY --from=go-builder $REMOTE_SOURCES_DIR/kubedock/app/kubedock $HOME/go/bin/kubedock
COPY --from=go-builder $REMOTE_SOURCES_DIR/stow/app/build/bin/ /usr/bin/
COPY --from=go-builder $REMOTE_SOURCES_DIR/stow/app/build/share/ /usr/share/
# Specifically copy the perl files since the directories don't match the builder
COPY --from=go-builder $REMOTE_SOURCES_DIR/stow/app/build/share/perl5/5.32/ /usr/share/perl5/vendor_perl/
COPY --from=go-builder /usr/share/perl5/File/Copy.pm /usr/share/perl5/File/Copy.pm
# Create symbolic links from /home/tooling/ -> /home/user/

RUN stow . -t /home/user/ -d /home/tooling/ --no-folding
    # .viminfo cannot be a symbolic link for security reasons, so copy it to /home/user/
RUN stat /home/tooling/.viminfo
RUN cp /home/tooling/.viminfo /home/user/.viminfo

# A last pass to make sure that an arbitrary user can write in $HOME
RUN chgrp -R 0 /home && chmod -R g=u /home

ENV HOME=/home/user
ENTRYPOINT [ "/entrypoint.sh" ]
WORKDIR /projects
CMD tail -f /dev/null
