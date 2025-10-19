import { Body, Controller, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateProjectDto } from './dto/create-project.dto';

@Controller('projects')
export class ProjectsController {
  constructor(private prisma: PrismaService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  async create(@Body() body: CreateProjectDto) {
    return this.prisma.project.create({ data: body as any });
  }

  @Get()
  async list(@Query() query: any) {
    const where: any = {};
    if (query.category) where.category = query.category;
    if (query.priceMin) where.budgetMin = { gte: Number(query.priceMin) };
    if (query.priceMax) where.budgetMax = { lte: Number(query.priceMax) };
    return this.prisma.project.findMany({ where });
  }

  @Get(':id')
  async get(@Param('id') id: string) {
    return this.prisma.project.findUnique({ where: { id }, include: { proposals: true } });
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id')
  async update(@Param('id') id: string, @Body() body: any) {
    return this.prisma.project.update({ where: { id }, data: body });
  }
}