import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import dotenv from 'dotenv';
import connectDB from './config/db';

dotenv.config();

const app = express();

// Middleware — allow all origins + explicit methods/headers for preflight
app.use(cors({
  origin: '*',
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  optionsSuccessStatus: 200,
}));
app.use(express.json());

// NOTE: no explicit app.options() handler — the cors() middleware above already
// terminates preflight requests (preflightContinue defaults to false). Express 5
// also rejects a bare '*' route path; it would need '/*splat'.

// Connect to MongoDB
connectDB();

// Routes
import authRoutes from './routes/authRoutes';
import groupRoutes from './routes/groupRoutes';
import goalRoutes from './routes/goalRoutes';
import userRoutes from './routes/userRoutes';

app.use('/api/auth', authRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/goals', goalRoutes);
app.use('/api/users', userRoutes);

const httpServer = http.createServer(app);
export const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  },
});

io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  // When a client opens a group dashboard, they join that group's room
  socket.on('join_group', (groupId: string) => {
    socket.join(groupId);
    console.log(`Socket ${socket.id} joined group ${groupId}`);
  });

  socket.on('leave_group', (groupId: string) => {
    socket.leave(groupId);
    console.log(`Socket ${socket.id} left group ${groupId}`);
  });

  // Global room for general user updates (like dashboard)
  socket.on('join_user', (userId: string) => {
    socket.join(`user_${userId}`);
    console.log(`Socket ${socket.id} joined user room ${userId}`);
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
  });
});

// Basic health check route
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'DuoFit API is running' });
});

// Start Server — bind to 0.0.0.0 so the host/platform can route traffic in
const PORT = process.env.PORT || 5000;
httpServer.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`Server running on port ${PORT} (accessible on local network)`);
});
