from setuptools import setup

setup(
    name="phdi_cloud_function_utils",
    version="0.0.1",
    description="Utilities for GCP Cloud Functions in the phdi-google-cloud repository.",  # noqa
    url="https://github.com/CDCgov/phdi-google-cloud/tree/main/cloud-functions/phdi_cloud_function_utils",  # noqa
    author="PHDI",
    license="CC0 1.0 Universal",
    packages=["phdi_cloud_function_utils"],
    package_data={
        "phdi_cloud_function_utils": [
            "./single_patient_bundle.json",
            "./multi_patient_obs_bundle.json",
            "upload_response.json",
        ]
    },
    install_requires=["flask"],
    zip_safe=False,
)
