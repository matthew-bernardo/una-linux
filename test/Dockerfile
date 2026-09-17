FROM fedora:44

# git/python3/ncurses: apply_config.sh and its helpers.
# ansible-core: playbooks once the install stubs are real.
RUN dnf -y install \
      git \
      python3 \
      ncurses \
      ansible-core \
    && dnf clean all \
    && git config --system --add safe.directory /una-setup

COPY entrypoint.sh /usr/local/bin/una-setup-test-entrypoint
RUN chmod +x /usr/local/bin/una-setup-test-entrypoint

WORKDIR /una-setup
ENTRYPOINT ["/usr/local/bin/una-setup-test-entrypoint"]
CMD ["bash"]
