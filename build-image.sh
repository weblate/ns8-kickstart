#!/bin/bash

# Terminate on error
set -e

# Prepare variables for later user
images=()
# The image willbe pushed to GitHub image registry under nethserver organization
repobase="ghcr.io/nethserver"
# Configure the image name
reponame="<MODULE_NAME>"

# Create a new empty container image
container=$(buildah from scratch)

# Reuse existing nodebuilder-<MODULE_NAME> container, to speed up builds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-<MODULE_NAME>; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-<MODULE_NAME> -v "${PWD}:/usr/src/<MODULE_NAME>:Z" docker.io/library/node:lts
fi

echo "Build static UI files with node..."
buildah run nodebuilder-<MODULE_NAME> sh -c "cd /usr/src/<MODULE_NAME>/ui && yarn install && yarn build"

# Add imageroot directory to the container image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
# Setup the entrypoint, ask to reserve one TCP port with the label and set a rootless container
buildah config --entrypoint=/ \
#    --label="org.nethserver.tcp-ports-demand=1" \
#    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.images=<MODULE_IMAGES>" \
    "${container}"
# Commit everything
buildah commit "${container}" "${repobase}/${reponame}"

images+=("${repobase}/${reponame}")

# Setup CI when pushing to Github
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "::set-output name=images::%s\n" "${images[*]}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@]}"; do printf "  buildah push %s docker://%s:0.0.1\n" "${image}" "${image}" ; done
    printf "\n"
fi