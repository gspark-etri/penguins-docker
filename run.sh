#docker run -it --shm-size=10g --ulimit memlock=-1  --cap-add=SYS_NICE --cap-add=SYS_RESOURCE  --device=/dev/infiniband/uverbs0 --device=/dev/infiniband/rdma_cm --gpus all --ipc=host --network=host --name penguin4 deepspeed-dev
docker run -it --shm-size=10g --ulimit memlock=-1  --cap-add=SYS_NICE --cap-add=SYS_RESOURCE  --gpus all --ipc=host --network=host --name penguin5 deepspeed-dev
