import setuptools

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setuptools.setup(
    name="mcvqoe-mouth2ear",
    author="PSCR",
    author_email="PSCR@PSCR.gov",
    description="Measurement code for measuring mouth to ear latency",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://gitlab.nist.gov/gitlab/PSCR/MCV/device-tst",
    packages=setuptools.find_namespace_packages(include=["mcvqoe.*"]),
    include_package_data=True,
    package_data={"mcvqoe": ["mouth2ear", "audio_clips", "*.wav"]},
    use_scm_version={"write_to": "mcvqoe/mouth2ear/version.py"},
    setup_requires=["setuptools_scm"],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: Public Domain",
        "Operating System :: OS Independent",
    ],
    license="NIST software License",
    install_requires=[
        "mcvqoe-base",
        "matplotlib",
        "plotly",
        "pandas",
        'numpy',
    ],
    entry_points={
        "console_scripts": [
            "m2e-sim=mcvqoe.mouth2ear.m2e_simulate:main",
            "m2e-measure=mcvqoe.mouth2ear.m2e_hw_test:main",
            "m2e-reprocess=mcvqoe.mouth2ear.m2e_reprocess:main",
        ],
    },
    python_requires=">=3.6",
)
