ARG BUILDER="ghcr.io/boukehaarsma23/aur-builder:main"
FROM ${BUILDER} AS builder

FROM ghcr.io/bootcrew/arch-bootc:latest

ARG PKG_INSTALL
ARG PKG_REMOVE

COPY --from=builder /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist
COPY --from=builder /tmp/repo /tmp/repo

RUN pacman-key --init && \
    sed -i 's|^#NoUpgrade *=.*|NoUpgrade = /etc/pacman.conf|' /etc/pacman.conf && \
    sed -i '/ParallelDownloads/s/^/#/g' /etc/pacman.conf && \
    sed -i '/^\[extra\]/i \
    [multilib]\nInclude = /etc/pacman.d/mirrorlist\n' /etc/pacman.conf && \
    cp /etc/pacman.conf /etc/pacman.conf.bak && \
    sed -i '/^\[extra\]/s/^/\[bouhaa\]\nSigLevel = Optional TrustAll\nServer = file:\/\/\/tmp\/repo\n\n/' /etc/pacman.conf && \
    if [ -n "$PKG_INSTALL" ]; then \
    yes | pacman -Syyuu --noconfirm --needed --overwrite '*' $PKG_INSTALL; \
    fi && \
    if [ -n "$PKG_REMOVE" ]; then \
    pacman -Rns --noconfirm $PKG_REMOVE; \
    pacman -Scc --noconfirm; \
    fi && \
    rm -rf /tmp/repo && \
    mv /etc/pacman.conf.bak /etc/pacman.conf && \
    pacman -S --noconfirm --clean && \
    cat /etc/pacman.conf
RUN bootc container lint