ARG BUILDER="ghcr.io/boukehaarsma23/chimeraos-builder:main"
FROM ${BUILDER} as builder

FROM archlinux:base as image
COPY --from=builder /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist
COPY --from=builder /tmp/repo /tmp/repo

# Run commands in container
RUN cp /etc/pacman.conf /etc/pacman.conf.bak && \
    sed -i '/^\[core\]/s/^/\[chos\]\nSigLevel = Optional TrustAll\nServer = file:\/\/\/tmp\/repo\n\n/' /etc/pacman.conf && \
    pacman --noconfirm -Syyuu --overwrite ="*" linux steamos-efi grub dracut && \ 
    mv /etc/pacman.conf.bak /etc/pacman.conf

FROM scratch
COPY --from=image / /