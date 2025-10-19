import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateProposalDto } from './dto/create-proposal.dto';

@Controller('projects/:projectId/proposals')
export class ProposalsController {
  constructor(private prisma: PrismaService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  async create(@Param('projectId') projectId: string, @Body() body: CreateProposalDto) {
    const payload = { ...body, projectId };
    return this.prisma.proposal.create({ data: payload as any });
  }

  @Get()
  async list(@Param('projectId') projectId: string) {
    return this.prisma.proposal.findMany({ where: { projectId } });
  }
}