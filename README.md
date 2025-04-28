# Distributed Transcription
A distributed data analysis pipeline that transcribes speech from audio files using OpenAI's Whisper (whisper-small). Slurm is used to manage the cluster, with NFS as the file storage backend and Redis for task queuing.

## Provision resources
```bash
cd infra
terraform init
terraform apply
```
## Configure machines
After provisioning, all ansible scripts have to be run from the host machine to configure the cluster and run jobs. The host node automatically pulls this repository upon creation.

```bash
cd /home/almalinux/distributed-transcription/ansible
ansible-playbook -i hosts install-playbook.yaml --key-file ~/.ssh/ansible_key
```
This playbook installs all the dependencies and scripts for the application. Now it's ready to process a dataset.

## Run the benchmark dataset
The benchmark dataset contains broadcasts from the WWII era, totaling approximately 1000 hours.
```bash
ansible-playbook -i hosts benchmark-playbook.yaml --key-file ~/.ssh/ansible_key
```
This will take 36 hours to run!

## Submit a new dataset
Ansible has been set up to download arbitrary data from Internet Archive as long as a list of item identifiers to download is present.

### Run the sample 
A few sample lists have been provided in the `dataset` role's files directory alongside the benchmark item list. 
- groks-physics-itemlist.txt: 28-minute [episode](https://archive.org/details/groks1041) of Groks Science podcast about the physics of existence. It should take about 30 seconds to run ansible and 3 minutes to finish transcribing.
- said-interview-itemlist.txt: 2-hour [interview](https://archive.org/details/AnEveningWithRayParkerJr) with the musician Ray Parker Jr. 30 sec to run ansible and 6 minutes to transcribe.

These can also be combined into one list to submit to the cluster as a group. 
Run the new-inputs-playbook with two variables: the name of the dataset and the name of the itemlist file. These have been set to the science podcast by default but can be overridden on the command line.
This playbook downloads the dataset, tailors the application for it (create folders, modify paths in the script, etc) and then runs the analysis. 
```bash
ansible-playbook -i hosts new-inputs-playbook.yaml --key-file ~/.ssh/ansible_key
```
or
```bash
ansible-playbook -i hosts new-inputs-playbook.yaml --key-file ~/.ssh/ansible_key --extra-vars "dataset_name=ray-interview itemlist_file=ray-parker-jr.txt"
```
- The dataset can be given any name but the itemlist path must exist in role's `files` folder.

View the system working at the Grafana dashboard. The results will be uploaded to the Minio server in a bucket called transcription-<dataset_name>; so the samples can be expected at [transcription-groks-physics](https://minio-ucabojm-cons.comp0235.condenser.arc.ucl.ac.uk/browser/transcription-groks-physics) and [transcription-ray-interview](https://minio-ucabojm-cons.comp0235.condenser.arc.ucl.ac.uk/browser/transcription-ray-interview).

### Run with your own data
If you find something cool on the Internet Archive yourself that you want to transcribe, the filelist will have to be generated yourself. Exact instructions on how to do this from your search query are found on their [website](https://blog.archive.org/2012/04/26/downloading-in-bulk-using-wget/). Or, you can find the identifier in the URL after "https://archive.org/details/". After generating this list, add it under the files for the dataset role.
```bash
mv <path_to_your_itemlist> /home/almalinux/distributed-transcription/ansible/roles/dataset/files
```
Then run the playbook as above.
```bash
ansible-playbook -i hosts new-inputs-playbook.yaml --key-file ~/.ssh/ansible_key --extra-vars "dataset_name=my-audio-data itemlist_file=my-item-list.txt"
```
Directly submitting own MP3 files is not yet supported.

## Terminate the transcription service at the end
```bash
ansible-playbook -i hosts stop-service.yaml --key-file ~/.ssh/ansible_key
```