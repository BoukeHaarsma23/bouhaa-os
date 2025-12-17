ARG BUILDER="ghcr.io/boukehaarsma23/aur-builder:main"
FROM ${BUILDER} AS builder

FROM ghcr.io/bootcrew/arch-bootc:latest AS image

ARG PKG_INSTALL
ARG PKG_REMOVE

COPY --from=builder /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist
COPY --from=builder /tmp/repo /tmp/repo

RUN pacman-key --init && \
    pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key F3B607488DB35A47 && \
    sed -i 's|^#NoUpgrade *=.*|NoUpgrade = /etc/pacman.conf|' /etc/pacman.conf && \
    sed -i '/ParallelDownloads/s/^/#/g' /etc/pacman.conf && \
    pacman -U --noconfirm \
    https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst \
    https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst \
    https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-22-1-any.pkg.tar.zst \
    https://mirror.cachyos.org/repo/x86_64/cachyos/pacman-7.1.0.r7.gb9f7d4a-3-x86_64.pkg.tar.zst &&\
    sed -i '/^\[core\]/i [cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist\n\n\
    [cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n\
    [cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n\
    [cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n' /etc/pacman.conf &&\
    sed -i '/^\[extra\]/i \
    [multilib]\nInclude = /etc/pacman.d/mirrorlist\n' /etc/pacman.conf && \
    cp /etc/pacman.conf /etc/pacman.conf.bak && \
    sed -i '/^\[cachyos\]/s/^/\[bouhaa\]\nSigLevel = Optional TrustAll\nServer = file:\/\/\/tmp\/repo\n\n/' /etc/pacman.conf && \
    if [ -n "$PKG_INSTALL" ]; then \
    pacman -Syy --noconfirm --needed --overwrite '*' $PKG_INSTALL; \
    fi && \
    if [ -n "$PKG_REMOVE" ]; then \
    pacman -Rns --noconfirm $PKG_REMOVE; \
    pacman -Scc --noconfirm; \
    fi && \
    mv /etc/pacman.conf.bak /etc/pacman.conf && \
    cat /etc/pacman.conf

FROM scratch
COPY --from=image / /
RUN bootc container lint