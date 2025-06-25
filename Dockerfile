# Stage 1: Build the application
FROM public.ecr.aws/docker/library/node:21 AS build

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install only production dependencies
RUN npm install --omit=dev

# Copy the rest of the application code
COPY . .

# Build the Next.js app
RUN npm run build

# Stage 2: Production-ready image
FROM public.ecr.aws/docker/library/node:21-alpine

# Install runtime dependencies needed by native modules
RUN apk add --no-cache libc6-compat

# Create a non-root user for improved security
RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001
USER nextjs

# Set the working directory in the production image
WORKDIR /app

# Copy build output and dependencies from the build stage
COPY --from=build /app/.next /app/.next
COPY --from=build /app/public /app/public
COPY --from=build /app/node_modules /app/node_modules
COPY --from=build /app/package*.json ./

# Expose the port the app runs on
EXPOSE 3000

# Start the application using the default start script
CMD ["npm", "start"]
