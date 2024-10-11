#!/usr/bin/env python

from collections.abc import Iterator
import json
import os
import subprocess


def iter_docker_layers(manifest_json_path: str) -> Iterator[str]:
    with open(manifest_json_path, "r") as f:
        manifests_json = json.load(f)
    for manifest_json in manifests_json:
        for layer in manifest_json["Layers"]:
            yield layer


def extract_docker_image(layers_dir: str, target_dir: str) -> None:
    manifest_json_path = os.path.join(layers_dir, "manifest.json")
    os.makedirs(target_dir, exist_ok=True)
    for layer_path in iter_docker_layers(manifest_json_path):
        layer_tar_path = os.path.join(layers_dir, layer_path)
        subprocess.run(
            [
                "tar",
                "--same-permissions",
                "--preserve-permissions",
                "-xvf",
                layer_tar_path,
                "-C",
                target_dir,
            ]
        )


def extract_layers_into_own_dir(layers_dir: str, target_dir: str) -> None:
    for layer_path in iter_docker_layers(os.path.join(layers_dir, "manifest.json")):
        layer_tar_path = os.path.join(layers_dir, layer_path)
        layer_dir = os.path.join(target_dir, os.path.basename(layer_path))
        os.makedirs(layer_dir, exist_ok=True)
        subprocess.run(
            [
                "tar",
                "--same-permissions",
                "--preserve-permissions",
                "-xvf",
                layer_tar_path,
                "-C",
                layer_dir,
            ]
        )


if __name__ == "__main__":
    if os.environ.get("OWNDIR", None):
        extract_layers_into_own_dir(".", "single-dir-extracted-fs")
    else:
        extract_docker_image(".", "extracted-fs")
