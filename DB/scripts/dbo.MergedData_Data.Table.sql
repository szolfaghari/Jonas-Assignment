USE [JonasDB]
GO
/****** Object:  Table [dbo].[MergedData_Data]    Script Date: 2/3/2020 1:37:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MergedData_Data](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[year] [int] NULL,
	[unit_id] [int] NULL,
	[field_id] [int] NULL,
	[value] [varchar](max) NULL,
 CONSTRAINT [PK_MergedData_Data] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
