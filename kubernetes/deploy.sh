#!/bin/bash

echo "🚀 Starting deployment of ITI Challenge applications..."

# Step 1: Create global IP address for load balancer
echo "📡 Creating global IP address..."
gcloud compute addresses create python-app-ip --global || echo "IP address might already exist"

# Step 2: Deploy Redis
echo "📦 Deploying Redis..."
kubectl apply -f redis-deployment.yaml

# Step 3: Wait for Redis to be ready
echo "⏳ Waiting for Redis to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/redis

# Step 4: Deploy Python app
echo "🐍 Deploying Python application..."
kubectl apply -f python-app-deployment.yaml

# Step 5: Wait for Python app to be ready
echo "⏳ Waiting for Python app to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/python-app

# Step 6: Deploy Ingress
echo "🌐 Creating Ingress and Load Balancer..."
kubectl apply -f ingress.yaml

# Step 7: Show status
echo "✅ Deployment complete! Checking status..."
echo ""
echo "Pods:"
kubectl get pods
echo ""
echo "Services:"
kubectl get services
echo ""
echo "Ingress:"
kubectl get ingress
echo ""
echo "Global IP:"
gcloud compute addresses describe python-app-ip --global --format="value(address)"

echo ""
echo "🎉 Deployment finished!"
echo "📝 Note: It may take 5-10 minutes for the load balancer to be fully ready."
echo "🌍 Your application will be available at the IP address shown above."
