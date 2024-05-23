import toml


def pin_dependencies(pyproject_path="pyproject.toml", poetry_lock_path="poetry.lock"):
    """Pins dependencies in pyproject.toml to the exact versions found in poetry.lock,
    handling metadata and compatibility markers."""

    with open(pyproject_path, "r") as pyproject_file:
        pyproject_data = toml.load(pyproject_file)

    with open(poetry_lock_path, "r") as lock_file:
        lock_data = toml.load(lock_file)

    dependencies = lock_data["package"]
    for dependency in dependencies:
        name = dependency["name"]

        # Skip git dependencies
        if dependency.get("source", {}).get("type") == "git":
            continue

        # Handle metadata and compatibility markers
        version = dependency["version"]
        pyproject_entry = pyproject_data["tool"]["poetry"]["dependencies"].get(name, {})

        if "^" in pyproject_entry:
            # Preserve compatibility marker if present
            version = f"^{version}"

        if isinstance(pyproject_entry, dict) and "version" in pyproject_entry:
            # Pin with metadata if present
            pyproject_data["tool"]["poetry"]["dependencies"][name] = {
                "version": version,
                **pyproject_entry,  # Keep any additional metadata
            }
        else:
            # Pin directly if no metadata
            pyproject_data["tool"]["poetry"]["dependencies"][name] = version

        # Check for dependencies within groups (with same logic as above)
        for group_name, group_deps in (
            pyproject_data["tool"]["poetry"].get("group", {}).items()
        ):
            if name in group_deps["dependencies"]:
                pyproject_entry = group_deps["dependencies"][name]

                if "^" in pyproject_entry:
                    version = f"^{version}"

                if isinstance(pyproject_entry, dict) and "version" in pyproject_entry:
                    group_deps["dependencies"][name] = {
                        "version": version,
                        **pyproject_entry,
                    }
                else:
                    group_deps["dependencies"][name] = version

    # Write the updated pyproject.toml
    with open(pyproject_path, "w") as pyproject_file:
        toml.dump(pyproject_data, pyproject_file)


if __name__ == "__main__":
    pin_dependencies()
