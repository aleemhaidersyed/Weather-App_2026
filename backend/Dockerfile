# =========================================================
# STAGE 1: The Builder Stage
# =========================================================
FROM python:3.12-alpine AS builder

WORKDIR /app

# Install system compilation tools needed for Python wheel packages
RUN apk add --no-cache gcc musl-dev libffi-dev

# Copy only the dependency list first (takes advantage of Docker caching)
COPY requirements.txt .

# Compile and build python packages into a wheels directory
RUN pip install --no-cache-dir --user -r requirements.txt


# =========================================================
# STAGE 2: The Final Secure Runner Stage
# =========================================================
FROM python:3.12-alpine

WORKDIR /app

# Create a restricted user and group for our app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 🌟 ADD THIS LINE: Upgrade pip to the latest secure version
RUN pip install --no-cache-dir --upgrade pip

# Copy compiled python libraries from the builder stage
COPY --from=builder /root/.local /home/appuser/.local
# Copy our application source code
COPY app.py .

# Grant ownership of the /app folder to our non-root user (important for SQLite file writes!)
RUN chown -R appuser:appgroup /app

# Switch to the secure non-root user context
USER appuser

# Expose the network port Flask runs on
EXPOSE 5000

# Set environment paths so Python can find our installed libraries
ENV PATH=/home/appuser/.local/bin:$PATH

# Define the command to start our app
CMD ["python", "app.py"]