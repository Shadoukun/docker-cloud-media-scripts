FROM alpine:latest

ENV RCLONE_VERSION="v1.42"
ENV RCLONE_RELEASE="rclone-${RCLONE_VERSION}-linux-amd64"
ENV RCLONE_ZIP="${RCLONE_RELEASE}.zip"
ENV RCLONE_URL="https://github.com/ncw/rclone/releases/download/${RCLONE_VERSION}/${RCLONE_ZIP}"

# Plexdrive compiled with musl libc
ENV PLEXDRIVE_BIN="plexdrive"
ENV PLEXDRIVE_URL="https://docs.google.com/uc?export=download&id=1N51dZU2eW7SY3fzSFxXTwLI40DaG5Kc5"

# dependencies
ENV DEPS \
    shadow \
    bash \
    bc \ 
    curl \
    fuse \
    unionfs-fuse \
    unzip \
    wget \
    ca-certificates \
    openssl

RUN apk update \
    && apk add --no-cache $DEPS \
    && sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf


# S6 overlay
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_KEEP_ENV=1

RUN OVERLAY_VERSION=$(curl -sX GET "https://api.github.com/repos/just-containers/s6-overlay/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
    curl -o /tmp/s6-overlay.tar.gz -L "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-amd64.tar.gz" && \
    tar xfz  /tmp/s6-overlay.tar.gz -C /

# Rclone
RUN cd /tmp \
    && wget "$RCLONE_URL" \
    && unzip "$RCLONE_ZIP" \
    && chmod a+x "${RCLONE_RELEASE}/rclone" \
    && cp -rf "${RCLONE_RELEASE}/rclone" "/usr/bin/rclone" \
    && rm -rf "$RCLONE_ZIP" \
    && rm -rf "$RCLONE_RELEASE"


# Plexdrive
RUN cd /tmp \
    && wget --no-check-certificate "$PLEXDRIVE_URL" -O $PLEXDRIVE_BIN \
    && chmod a+x "$PLEXDRIVE_BIN" \
    && cp -rf "$PLEXDRIVE_BIN" "/usr/bin/plexdrive" \
    && rm -rf "$PLEXDRIVE_BIN"


####################
# ENVIRONMENT VARIABLES
####################
# Encryption
ENV ENCRYPT_MEDIA "1"
ENV READ_ONLY "1"

# Rclone
ENV BUFFER_SIZE "512M"
ENV CHECKERS "16"
ENV RCLONE_CLOUD_ENDPOINT "gd-crypt:"
ENV RCLONE_LOCAL_ENDPOINT "local-crypt:"
ENV RCLONE_VERBOSE "0"
ENV RCLONE_LOG_LEVEL "NOTICE"
ENV RCLONE_REMOTE_CONTROL "0"

# Rclone Mirror Settings
ENV MIRROR_MEDIA "0"
ENV RCLONE_MIRROR_ENDPOINT "gdm-crypt:"
ENV ENCRYPT_MIRROR_MEDIA "1"
ENV MIRROR_BWLIMIT "100M"
ENV MIRROR_TRANSFERS "4"
ENV MIRROR_TPS_LIMIT "1"
ENV MIRROR_TPS_LIMIT_BURST "1"

# Plexdrive
ENV CHUNK_SIZE "10M"
ENV CLEAR_CHUNK_MAX_SIZE ""
ENV CLEAR_CHUNK_AGE "24h"
ENV CHUNK_SIZE "10M"
ENV CHUNK_CHECK_THREADS "2"
ENV CHUNK_LOAD_THREADS "2"
ENV CHUNK_LOAD_AHEAD "3"
ENV MAX_CHUNKS "10"

# Time format
ENV DATE_FORMAT "+%F@%T"

# Local files removal
ENV REMOVE_LOCAL_FILES_BASED_ON "space"
ENV REMOVE_LOCAL_FILES_WHEN_SPACE_EXCEEDS_GB "100"
ENV FREEUP_ATLEAST_GB "80"
ENV REMOVE_LOCAL_FILES_AFTER_DAYS "30"

# Plex
ENV PLEX_URL ""
ENV PLEX_TOKEN ""


####################
# SCRIPTS
####################
COPY setup/* /usr/bin/
COPY scripts/* /usr/bin/
COPY root /

RUN chmod a+x /usr/bin/* && \
    groupmod -g 1000 users && \
	useradd -u 911 -U -d / -s /bin/false abc && \
	usermod -G users abc && \
    rm -rf /tmp/*

####################
# VOLUMES
####################
# Define mountable directories.
#VOLUME /data/db /config /cloud-encrypt /cloud-decrypt /local-decrypt /local-media /chunks /log
VOLUME /config /cloud-encrypt /cloud-decrypt /local-decrypt /local-media /chunks /log

RUN chmod -R 777 /log

####################
# WORKING DIRECTORY
####################
WORKDIR /data

####################
# ENTRYPOINT
####################
ENTRYPOINT ["/init"]
