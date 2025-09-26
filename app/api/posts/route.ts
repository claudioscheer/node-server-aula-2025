import { NextRequest, NextResponse } from 'next/server';
import { PrismaClient } from '../../generated/prisma';
import jwt from 'jsonwebtoken';

const prisma = new PrismaClient();

// Helper function to verify JWT token
async function verifyToken(request: NextRequest) {
  try {
    const authHeader = request.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    const token = authHeader.substring(7);
    const jwtSecret = process.env.JWT_SECRET;
    
    if (!jwtSecret) {
      return null;
    }

    const decoded = jwt.verify(token, jwtSecret) as any;
    return decoded;
  } catch (error) {
    return null;
  }
}

export async function GET(request: NextRequest) {
  try {
    // Verify authentication
    const user = await verifyToken(request);
    if (!user) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      );
    }

    const { searchParams } = new URL(request.url);
    
    // Parse pagination parameters
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '10');
    
    // Validate pagination parameters
    if (page < 1) {
      return NextResponse.json(
        { error: 'Page must be greater than 0' },
        { status: 400 }
      );
    }
    
    if (limit < 1 || limit > 50) {
      return NextResponse.json(
        { error: 'Limit must be between 1 and 50' },
        { status: 400 }
      );
    }

    // Calculate offset for page-based pagination
    const offset = (page - 1) * limit;

    // Build query options
    const queryOptions = {
      take: limit,
      skip: offset,
      orderBy: {
        createdAt: 'desc' as const
      },
      include: {
        author: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }
      }
    };

    // Fetch posts
    const posts = await prisma.post.findMany(queryOptions);

    // Get total count for pagination metadata
    const totalCount = await prisma.post.count();
    const totalPages = Math.ceil(totalCount / limit);

    // Determine if there are more posts
    const hasNextPage = page < totalPages;

    return NextResponse.json({
      posts,
      pagination: {
        currentPage: page,
        totalPages,
        totalCount,
        hasNextPage,
        limit
      }
    });

  } catch (error) {
    console.error('Posts fetch error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    // Verify authentication
    const user = await verifyToken(request);
    if (!user) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      );
    }

    const { title, description, imagePath } = await request.json();

    // Validate input
    if (!title || !description) {
      return NextResponse.json(
        { error: 'Title and description are required' },
        { status: 400 }
      );
    }

    if (title.length > 200) {
      return NextResponse.json(
        { error: 'Title must be 200 characters or less' },
        { status: 400 }
      );
    }

    if (description.length > 2000) {
      return NextResponse.json(
        { error: 'Description must be 2000 characters or less' },
        { status: 400 }
      );
    }

    // Create the post
    const post = await prisma.post.create({
      data: {
        title: title.trim(),
        description: description.trim(),
        imagePath: imagePath?.trim() || null,
        authorId: user.userId
      },
      include: {
        author: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }
      }
    });

    return NextResponse.json({
      message: 'Post created successfully',
      post
    }, { status: 201 });

  } catch (error) {
    console.error('Post creation error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
