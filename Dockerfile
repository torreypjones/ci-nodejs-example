# Stage 1: Build the application
FROM node:21 AS build

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Build the application
RUN npm run build

# Stage 2: Production-ready image
FROM node:21-alpine

# Set the working directory in the production image
WORKDIR /app

# Copy only the necessary files from the build stage

# COPY --from=build /app/dist /app/dist
COPY package*.json ./

# Install only production dependencies
RUN npm install --production

# Expose the port the app runs on
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
