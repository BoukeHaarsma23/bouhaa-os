ARG BUILDER="ghcr.io/boukehaarsma23/chimeraos-builder:main"
FROM ${BUILDER} as builder

FROM archlinux:base as image
COPY --from=builder /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist
COPY --from=builder /tmp/repo /tmp/repo
COPY steamos-* /usr/bin/

# Run commands in container
RUN cp /etc/pacman.conf /etc/pacman.conf.bak && \
    sed -i '/^\[core\]/s/^/\[chos\]\nSigLevel = Optional TrustAll\nServer = file:\/\/\/tmp\/repo\n\n/' /etc/pacman.conf && \
    pacman --noconfirm -Syyuu --overwrite ="*" linux-chimeraos chos/steamos-efi grub dracut zsh && \
    rm -rf /tmp/repo && \ 
    mkdir -p esp && \
    mkdir -p efi && \
    mv /etc/pacman.conf.bak /etc/pacman.conf

FROM scratch
COPY --from=image / /