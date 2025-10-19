import { IsNotEmpty, IsNumber, IsOptional, IsString, IsArray } from 'class-validator';

export class CreateProjectDto {
  @IsNotEmpty()
  @IsString()
  title!: string;

  @IsNotEmpty()
  @IsString()
  description!: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsNumber()
  budgetMin!: number;

  @IsNumber()
  budgetMax!: number;

  @IsOptional()
  @IsArray()
  attachments?: any[];
}