FROM node:22-bookworm

# Install global npm packages into a directory owned by the node user.
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV PATH=$PATH:/home/node/.npm-global/bin

RUN mkdir -p /home/node/.claude \
    /home/node/.codex \
    /home/node/.npm-global \
    /workspace \
    && chown -R node:node /home/node /workspace

USER node
WORKDIR /workspace

# Install Claude Code, CodeGraph, and OpenAI Codex CLI.
RUN npm install -g \
    @anthropic-ai/claude-code \
    @colbymchenry/codegraph \
    @openai/codex