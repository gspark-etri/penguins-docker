docker run -it \
  --shm-size=10g \
  --ulimit memlock=-1 \
  --cap-add=SYS_NICE \
  --cap-add=SYS_RESOURCE \
  --device=/dev/infiniband \
  --gpus all \
  --ipc=host \
  --network=host \
  --name penguin-rdma \
  -v /data/cache/huggingface:/root/.cache \
  deepspeed-dev
