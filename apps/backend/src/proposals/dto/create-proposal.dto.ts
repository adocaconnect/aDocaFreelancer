import { IsNotEmpty, IsNumber, IsString, Min } from 'class-validator';

export class CreateProposalDto {
  @IsNotEmpty()
  @IsString()
  freelancerId!: string;

  @IsNotEmpty()
  @IsString()
  coverLetter!: string;

  @IsNumber()
  @Min(0)
  price!: number;

  @IsNumber()
  @Min(1)
  days!: number;
}