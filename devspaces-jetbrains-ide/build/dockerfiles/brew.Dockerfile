# Copyright (c) 2024-2025 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

# The Dockerfile works only in Brew, as it is customized for Cachito fetching
# project sources and npm dependencies, and performing an offline build with them

# The image to get the Node.js binary to support running an IDE in a UBI8-based user container.
# https://registry.access.redhat.com/ubi8/nodejs-20
FROM registry.redhat.io/ubi8/nodejs-20:1-73.1742991506 as ubi8

# https://registry.access.redhat.com/ubi9/nodejs-20
FROM registry.redhat.io/ubi9/nodejs-20:9.5-1743584090

USER 0

# cachito:yarn step 1: copy cachito sources where we can use them; source env vars; set working dir
COPY $REMOTE_SOURCES $REMOTE_SOURCES_DIR

# hadolint ignore=SC2086
RUN source $REMOTE_SOURCES_DIR/devspaces-images-jetbrains-ide/cachito.env

# It's important to build the status-app in the sources dir.
# Since there's .npmrc file that contains a relative path to the certificates
# required for accessing the Cachito npm cache.
WORKDIR $REMOTE_SOURCES_DIR/devspaces-images-jetbrains-ide/app/devspaces-jetbrains-ide/status-app
RUN npm install

WORKDIR $REMOTE_SOURCES_DIR/devspaces-images-jetbrains-ide/app/devspaces-jetbrains-ide/

RUN cp -r status-app /status-app/
RUN cp -r build/scripts/*.sh /

# Copy the JetBrains IDE's config where some settings are overridden for Che CDE needs.
RUN cp -r build/jetbrains_configs/idea.properties /

# Create a folders structure for mounting a shared volume and copy the editor binaries to.
RUN mkdir -p /idea-server/status-app

# Adjust permissions on some items so they're writable by group root.
# hadolint ignore=SC2086
RUN for f in "${HOME}" "/etc/passwd" "/etc/group" "/status-app" "/idea-server"; do\
        chgrp -R 0 ${f} && \
        chmod -R g+rwX ${f}; \
    done

# to provide to a UBI8-based user's container
COPY --from=ubi8 /usr/bin/node /node-ubi8

# Switch to unprivileged user.
USER 1001

ENTRYPOINT /entrypoint.sh

ENV SUMMARY="Red Hat OpenShift Dev Spaces with JetBrains IDE container" \
    DESCRIPTION="Red Hat OpenShift Dev Spaces with JetBrains IDE container" \
    PRODNAME="devspaces" \
    COMPNAME="jetbrains-ide-rhel9"
LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="$DESCRIPTION" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME-container" \
      name="$PRODNAME/$COMPNAME" \
      version="3.20" \
      license="EPLv2" \
      maintainer="Artem Zatsarynnyi <azatsary@redhat.com>, Samantha Dawley <sdawley@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""
