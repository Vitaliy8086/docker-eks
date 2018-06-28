FROM alpine:latest
RUN apk -v --update add \
        python \
        py-pip \
        curl && \
    pip install --upgrade awscli python-magic && \
    rm /var/cache/apk/*

WORKDIR /src
ADD . /src/

RUN mkdir -p /src/.aws

# No need to hardcore the value below:

ARG AWS_ACCESS_KEY=xxx
ARG AWS_SECRET_KEY=yyy
ARG REGION=zzz

ENV aws_access_key_id=${AWS_ACCESS_KEY} \
    aws_secret_access_key=${AWS_SECRET_KEY} \
    region=${REGION}

RUN echo [default] > /src/.aws/credentials && \
    env | grep aws_ >> /src/.aws/credentials && \
    env | grep region >> /src/.aws/credentials

RUN export AWS_CONFIG_FILE=/src/.aws/credentials && \
    aws iam create-role --role-name eks --assume-role-policy-document file:///src/eks-svc-policy.json && \
    aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSServicePolicy --role-name eks && \
    aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy --role-name eks && \
    aws cloudformation create-stack --stack-name eks-network --template-body file:///src/vars-eks-vpc.yaml --region $region

RUN mkdir -p /src/.kube

COPY kubectl /bin/kubectl

RUN chmod +x /bin/kubectl

COPY heptio-authenticator-aws /bin/heptio-authenticator-aws

RUN chmod +x /bin/heptio-authenticator-aws

COPY cluster.sh  /bin/cluster.sh

RUN chmod +x /bin/cluster.sh

RUN export AWS_CONFIG_FILE=/src/.aws/credentials && . /bin/cluster.sh

CMD [ "tail", "-F", "-n0", "/etc/hosts"  ]
