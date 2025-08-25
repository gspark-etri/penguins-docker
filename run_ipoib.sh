docker run -it \
  --shm-size=10g \
  --ulimit memlock=-1 \
  --cap-add=SYS_NICE \
  --cap-add=SYS_RESOURCE \
  --gpus all \
  --ipc=host \
  --network=host \
  --name ipoib \
  -v /data/cache/huggingface:/root/.cache/huggingface \
  -v /data/cache/torch:/root/.cache/torch \
  -v /data/cache/tfhub:/root/.cache/tfhub_modules \
  deepspeed-dev
