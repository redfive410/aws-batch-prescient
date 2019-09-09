FROM amazonlinux:latest

RUN yum update -y
RUN yum install python3 python3-dev -y

ENV APP_ROOT /usr/src/app
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT

ADD requirements.txt $APP_ROOT/
RUN pip3 install -r requirements.txt

ADD . $APP_ROOT/
# CMD ["python3", "main.py"]
