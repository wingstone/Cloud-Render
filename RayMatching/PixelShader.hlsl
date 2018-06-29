cbuffer timebuffer
{
	float Time;		//单位为秒
	float ScreenWidth;
	float ScreenHeight;
	float padding;
};

struct PS_INPUT
{
	float4 Pos : SV_POSITION;
	float2 xy : TEXCOORD0;			//( -ScreenWidth / 2 ~ ScreenWidth / 2, -ScreenHeight / 2 ~ ScreenHeight / 2 )
};

///////////////////////////////////////////////////////////////////////////////
//Ray Matching Code

#define DELTA 0.001

#define HIGHT_QUALITY

struct Ray
{
	float3 dir;
	float3 pos;
};

struct Sphere
{
	float3 center;
	float redius;
	float3 color;
};

float Length(float3 pos, Sphere ball)
{
	return distance(pos, ball.center) - ball.redius;
}

//=======================Background Color===========================//
float3 GetBGColor(float2 xy)
{
	return float3(0.7, 0.4, 0.3)*(1 - 0.25*length(xy));
}

float3 GetSkyColor(float2 xy)
{
	float len = length(xy - float2(0.5, 0.5));
	float3 color1 = float3(0.0, 0.75, 0.9)*(1 - 0.05*len);
	float3 color2 = lerp(color1, float3(0.8, 0.7, 0.8), 1 - len);
	float3 sunCol = lerp(color2, float3(0.85, 0.75, 0.85), smoothstep(0.8, 0.95, 1 - len));
	return sunCol;
}

//=======================RayMatching Color===========================//
float3 RayMatching(float2 xy)
{
	//set View matrix
	float3 cameraPos = float3(0.0, 0.0, -10.0);
	float3 at = float3(0.0, 0.0, 0.0);
	float3 up = float3(0.0, 1.0, 0.0);

	matrix trans = (matrix)0; trans[3] = float4(-cameraPos, 1.0); trans[0][0] = trans[1][1] = trans[2][2] = trans[3][3] = 1;

	float3 front = normalize((at - cameraPos).xyz);
	float3 right = cross(up, front);
	up = cross(front, right);

	matrix rotate = (matrix)0; rotate[0] = float4(right, 0.0); rotate[1] = float4(up, 0.0); rotate[2] = float4(front, 0.0); rotate[3][3] = 1;

	matrix View = mul(trans, rotate);

	//set ray
	Ray ray;
	ray.dir = normalize(float3(xy, 1.732));		//y方向fov为60度
	ray.pos = float3(0, 0, 0);

	//set sphere
	Sphere ball;
	ball.center = float3(0, 0, 5);
	ball.center = mul(float4(ball.center, 1.0), View).xyz;
	ball.redius = 2.0;
	ball.color = float3(0.8, 0.8, 0.4);

	//set light
	float3 LightColor = float3(1.0, 1.0, 1.0);
	float3 LightDir = float3(1.0, 0.0, 0.0);

	//用来计算 图元法线
	float3 assistArray[4];
	assistArray[0] = normalize(float3(1.0, 1.0, 1.0));
	assistArray[1] = normalize(float3(-1.0, 1.0, -1.0));
	assistArray[2] = normalize(float3(1.0, -1.0, -1.0));
	assistArray[3] = normalize(float3(-1.0, -1.0, 1.0));

	float len = 0;
	float3 color;
	for (int i = 0; i < 30; i++)
	{
		len = Length(ray.pos, ball);
		if (len < DELTA)
		{
			float3 normal = float3(0, 0, 0);
			for (int j = 0; j < 4; j++)
			{
				normal += Length(ray.pos + assistArray[j] * DELTA, ball) * assistArray[j];
			}
			normal = normalize(normal);

			color = saturate(dot(normal, LightDir)) * LightColor * ball.color;
			break;
		}
		else
		{
			ray.pos += ray.dir*len;
			if (i == 29)	//background
			{
				color = GetBGColor(xy);
			}
		}
	}

	return color;
}

//=======================Varied Color===========================//
float3 GetVaryColor(float2 xy)
{
	float3 color = 0.5 + 0.5*sin(xy.xyx + float3(0, 2, 4) + Time);

	return color;
}

//=======================3D Perlin Noise================================//
//用于计算索引梯度的随机数序列， 用于3D
static int RandomNumber[256] = {
	0, 238, 228, 55, 137, 246, 138, 210, 106, 131, 0, 2, 237, 224, 121, 248, 74, 136, 107, 165, 157, 122, 145, 217, 175, 79, 198, 153, 90, 138, 16, 47,
	194, 234, 171, 103, 235, 48, 1, 250, 218, 78, 232, 126, 17, 70, 205, 185, 142, 141, 216, 89, 227, 112, 237, 134, 93, 10, 135, 57, 48, 241, 119, 223,
	115, 208, 64, 3, 52, 18, 13, 25, 134, 112, 203, 79, 146, 18, 200, 104, 130, 12, 10, 204, 178, 182, 75, 81, 253, 37, 9, 224, 169, 199, 202, 233,
	214, 8, 11, 64, 6, 202, 132, 124, 128, 191, 210, 114, 165, 157, 244, 74, 66, 30, 183, 35, 230, 171, 45, 188, 132, 238, 6, 15, 8, 45, 112, 190,
	166, 225, 120, 138, 7, 135, 97, 184, 136, 142, 76, 243, 228, 217, 172, 95, 49, 191, 157, 138, 16, 166, 2, 43, 218, 78, 187, 24, 196, 117, 116, 83,
	79, 20, 204, 195, 37, 105, 66, 186, 188, 254, 154, 88, 94, 58, 216, 171, 65, 166, 221, 72, 143, 229, 174, 255, 223, 76, 175, 185, 203, 73, 244, 19,
	26, 249, 164, 207, 13, 233, 58, 199, 125, 226, 205, 17, 12, 170, 205, 159, 118, 16, 214, 29, 151, 43, 195, 105, 102, 204, 228, 216, 186, 137, 239, 115,
	10, 135, 62, 101, 150, 8, 158, 88, 108, 22, 203, 172, 24, 156, 243, 52, 127, 15, 66, 186, 115, 214, 124, 238, 53, 58, 105, 64, 4, 97, 13, 243,
};

static int RandomIndex[256] = {
	2, 10, 8, 2, 8, 3, 7, 0, 9, 5, 0, 0, 8, 9, 4, 3, 9, 2, 4, 7, 5, 4, 8, 9, 0, 2, 5, 10, 0, 8, 3, 11, 
	11, 5, 5, 5, 5, 9, 8, 0, 9, 8, 3, 11, 4, 1, 8, 11, 5, 3, 11, 10, 10, 7, 0, 10, 1, 10, 2, 5, 10, 8, 0, 0, 
	1, 0, 1, 3, 4, 10, 9, 0, 6, 3, 9, 8, 0, 8, 5, 11, 6, 5, 4, 8, 9, 5, 1, 3, 5, 6, 3, 7, 6, 2, 2, 1, 
	7, 3, 9, 3, 0, 5, 7, 6, 5, 10, 3, 6, 10, 3, 9, 4, 4, 3, 11, 4, 3, 3, 2, 8, 11, 9, 10, 9, 7, 2, 5, 4, 
	0, 8, 1, 8, 11, 2, 11, 0, 9, 10, 2, 10, 1, 6, 5, 1, 9, 10, 2, 3, 3, 9, 9, 4, 0, 1, 4, 2, 7, 10, 11, 3, 
	5, 11, 5, 1, 2, 0, 5, 2, 4, 10, 6, 5, 1, 4, 6, 4, 4, 8, 11, 9, 11, 2, 1, 3, 11, 9, 8, 9, 9, 8, 5, 11, 
	11, 11, 5, 2, 0, 4, 11, 8, 4, 0, 11, 4, 2, 3, 2, 8, 6, 11, 10, 11, 10, 1, 4, 3, 10, 2, 1, 5, 4, 7, 4, 7, 
	5, 7, 6, 2, 10, 4, 3, 11, 9, 3, 4, 11, 2, 8, 0, 8, 6, 11, 2, 10, 10, 6, 0, 9, 6, 2, 3, 9, 2, 5, 4, 8, 
};

static int RandomIndex_Low[12] = {
	2, 1, 0, 2, 4, 10, 10, 1, 7, 11, 7, 11
};

static float3 Gradiant[12] = {
	{ 1, 1, 0 }, { 1, -1, 0 }, { -1, -1, 0 }, { -1, 1, 0 },
	{ 0, 1, 1 }, { 0, -1, 1 }, { 0, -1, -1 }, { 0, 1, -1 },
	{ 1, 0, 1 }, { -1, 0, 1 }, { 1, 0, -1 }, { -1, 0, -1 }
};

//更复杂，但是效果更好的平滑插值方法
float highLerp(float t)
{
	return t*t*t*(t*(t * 6 - 15) + 10);
}

//用于计算2D下的向量与梯度的点积  其实就是3D PerlinNoise在z = 0处的截面
float dotGridGradient2D(int ix, int iy, float x, float y)
{
	int index = RandomIndex[RandomNumber[ (RandomNumber[ix % 256] + iy) % 256]];
	float3 grad = Gradiant[index];

	return dot(grad, float3(x, y, 0));	
}

float dotGridGradient3D(int3 pos, float3 frac)
{
	int index = RandomIndex[ (RandomNumber[ (RandomNumber[pos.x % 256] + pos.y) % 256] + pos.z) % 256 ];
	float3 grad = Gradiant[index];

		return dot(grad, frac);
}

//随机性不是很好，但是高效的随机数用来求点积
float dotGridGradient2D_Low(int ix, int iy, float x, float y)
{
	int index = RandomIndex_Low[ RandomIndex_Low[(RandomIndex_Low[ix % 12] + iy) % 12] ];
	float3 grad = Gradiant[index];

	return dot(grad, float3(x, y, 0));
}

float dotGridGradient3D_Low(int3 pos, float3 frac)
{
	int index = RandomIndex_Low[(RandomIndex_Low[(RandomIndex_Low[pos.x % 12] + pos.y) % 12] + pos.z) % 12];
	float3 grad = Gradiant[index];

	return dot(grad, frac);
}

//xy : (0, 0) - (screenWidth, screenHeight);
float PerlinNoise2D(float2 xy, float frequency)		//pixel coord
{
	xy = xy * frequency;

	int x0 = floor(xy.x);
	int y0 = floor(xy.y);

	float dx = xy.x - x0;
	float dy = xy.y - y0;

	x0 = (x0 % 256 + 256) % 256;		//处理xyz为负数的情况
	y0 = (y0 % 256 + 256) % 256;

	int x1 = x0 + 1;
	int y1 = y0 + 1;

	float4 noise;
#ifdef HIGHT_QUALITY
	noise.x = dotGridGradient2D(x0, y0, dx, dy);
	noise.y = dotGridGradient2D(x0, y1, dx, dy - 1);
	noise.z = dotGridGradient2D(x1, y0, dx - 1, dy);
	noise.w = dotGridGradient2D(x1, y1, dx - 1, dy - 1);
#else
	noise.x = dotGridGradient2D_Low(x0, y0, dx, dy);
	noise.y = dotGridGradient2D_Low(x0, y1, dx, dy - 1);
	noise.z = dotGridGradient2D_Low(x1, y0, dx - 1, dy);
	noise.w = dotGridGradient2D_Low(x1, y1, dx - 1, dy - 1);
#endif

	dx = smoothstep(0, 1, dx);
	dy = smoothstep(0, 1, dy);
	float2 midNoise;
	midNoise.x = lerp(noise.x, noise.z, dx);
	midNoise.y = lerp(noise.y, noise.w, dx);

	return lerp(midNoise.x, midNoise.y, dy);
}

//xyz : (0, 0, 0) - (screenWidth, screenHeight, screenHeight);
float PerlinNoise3D(float3 xyz, float frequency)		//pixel coord
{
	xyz = xyz * frequency;

	int x0 = floor(xyz.x);
	int y0 = floor(xyz.y);
	int z0 = floor(xyz.z);

	float dx = xyz.x - x0;
	float dy = xyz.y - y0;
	float dz = xyz.z - z0;

	x0 = (x0 % 256 + 256) % 256;		//处理xyz为负数的情况
	y0 = (y0 % 256 + 256) % 256;
	z0 = (z0 % 256 + 256) % 256;

	int x1 = x0 + 1;
	int y1 = y0 + 1;
	int z1 = z0 + 1;

	float4 noise0, noise1;
#ifdef HIGHT_QUALITY
	noise0.x = dotGridGradient3D(int3(x0, y0, z0), float3(dx, dy, dz));
	noise0.y = dotGridGradient3D(int3(x0, y1, z0), float3(dx, dy - 1.0, dz));
	noise0.z = dotGridGradient3D(int3(x1, y0, z0), float3(dx - 1.0, dy, dz));
	noise0.w = dotGridGradient3D(int3(x1, y1, z0), float3(dx - 1.0, dy - 1.0, dz));

	noise1.x = dotGridGradient3D(int3(x0, y0, z1), float3(dx, dy, dz - 1.0));
	noise1.y = dotGridGradient3D(int3(x0, y1, z1), float3(dx, dy - 1.0, dz - 1.0));
	noise1.z = dotGridGradient3D(int3(x1, y0, z1), float3(dx - 1.0, dy, dz - 1.0));
	noise1.w = dotGridGradient3D(int3(x1, y1, z1), float3(dx - 1.0, dy - 1.0, dz - 1.0));
#else
	noise0.x = dotGridGradient3D_Low( int3(x0, y0, z0), float3(dx, dy, dz) );
	noise0.y = dotGridGradient3D_Low( int3(x0, y1, z0), float3(dx, dy - 1.0, dz) );
	noise0.z = dotGridGradient3D_Low( int3(x1, y0, z0), float3(dx - 1.0, dy, dz) );
	noise0.w = dotGridGradient3D_Low( int3(x1, y1, z0), float3(dx - 1.0, dy - 1.0, dz) );

	noise1.x = dotGridGradient3D_Low( int3(x0, y0, z1), float3(dx, dy, dz - 1.0) );
	noise1.y = dotGridGradient3D_Low( int3(x0, y1, z1), float3(dx, dy - 1.0, dz - 1.0) );
	noise1.z = dotGridGradient3D_Low( int3(x1, y0, z1), float3(dx - 1.0, dy, dz - 1.0) );
	noise1.w = dotGridGradient3D_Low( int3(x1, y1, z1), float3(dx - 1.0, dy - 1.0, dz - 1.0) );
#endif
	
	dx = smoothstep(0, 1, dx);
	dy = smoothstep(0, 1, dy);
	dz = smoothstep(0, 1, dz);

	float4 midNoise4;
	midNoise4.x = lerp(noise0.x, noise1.x, dz);
	midNoise4.y = lerp(noise0.y, noise1.y, dz);
	midNoise4.z = lerp(noise0.z, noise1.z, dz);
	midNoise4.w = lerp(noise0.w, noise1.w, dz);

	float2 midNoise2;
	midNoise2.x = lerp(midNoise4.x, midNoise4.y, dy);
	midNoise2.y = lerp(midNoise4.z, midNoise4.w, dy);

	return lerp(midNoise2.x, midNoise2.y, dx);
}

//===============================using Perlin================================//
float FractalNoise2D(float2 xy, float frequency)
{
	float gray = PerlinNoise2D(xy, frequency) + 0.5*PerlinNoise2D(xy, 2 * frequency) + 0.25*PerlinNoise2D(xy, 4 * frequency) + 0.125*PerlinNoise2D(xy, 8 * frequency);
	gray = (gray + 1)*0.5;
	gray = clamp(gray, 0, 1);
	return gray;
}

float FractalNoise3D(float3 xyz, float frequency)
{
	float gray = PerlinNoise3D(xyz, frequency) + 0.5*PerlinNoise3D(xyz, 2 * frequency) + 0.25*PerlinNoise3D(xyz, 4 * frequency) + 0.125*PerlinNoise3D(xyz, 8 * frequency);
	//gray = (gray + 1)*0.5;
	gray = clamp(gray, 0, 1);
	return gray;
}


//Turbulence texture
float Turbulence(float2 xy, float frequency)
{
	float gray =  abs( PerlinNoise2D(xy, frequency) ) + abs( 0.5*PerlinNoise2D(xy, 2 * frequency) )+ abs( 0.25*PerlinNoise2D(xy, 4 * frequency) ) + abs( 0.125*PerlinNoise2D(xy, 8 * frequency) );
	gray = clamp(gray, 0, 1);
	
	//// another is :
	//float gray = abs(PerlinNoise2D(xy, frequency) + 0.5*PerlinNoise2D(xy, 2 * frequency) + 0.25*PerlinNoise2D(xy, 4 * frequency) + 0.125*PerlinNoise2D(xy, 8 * frequency));
	//gray = (gray + 1)*0.5;
	//gray = clamp(gray, 0, 1);

	return gray;
}

//Wooden texture
float Wooden(float2 xy, float frequency)
{
	float gray = PerlinNoise2D(xy, frequency) * 10;
	return frac(gray);
}

//Marble texture
float Marble(float2 xy, float frequency)
{
	float noise = PerlinNoise2D(xy, frequency) + 0.5*PerlinNoise2D(xy, 2 * frequency) + 0.25*PerlinNoise2D(xy, 4 * frequency) + 0.125*PerlinNoise2D(xy, 8 * frequency);
	float g = sin((xy.x * 0.03 + noise) );
	return (g + 1.0) / 2.0;
}

//=======================================Volumetric render test======================//
float3 GetVoxelColor(float density, float dist)
{
	return lerp(float3(0.9, 0.8, 0.7), float3(0.4, 0.1, 0.05), density*density);
}

float3 Volumetric(float2 xy)
{
	//set View matrix
	float3 cameraPos = float3(5 * sin(Time*0.3), 0.0, 5.0*cos(Time*0.3));
		float3 at = float3(0.0, 0.0, 0.0);
		float3 up = float3(0.0, 1.0, 0.0);

		matrix trans = (matrix)0; trans[3] = float4(cameraPos, 1.0); trans[0][0] = trans[1][1] = trans[2][2] = trans[3][3] = 1;

	float3 front = normalize((at - cameraPos).xyz);
		float3 right = cross(up, front);
		up = cross(front, right);

	matrix rotate = (matrix)0; rotate[0] = float4(right, 0.0); rotate[1] = float4(up, 0.0); rotate[2] = float4(front, 0.0); rotate[3][3] = 1;

	matrix View = mul(rotate, trans);

	//set ray
	Ray ray;
	ray.dir = normalize(float3(xy, 1.732));		//y方向fov为60度
	ray.pos = float3(0, 0, 0);
	
	ray.dir = mul(float4(ray.dir, 0.0), View).xyz;		//变换射线位置和方向
	ray.pos = mul(float4(ray.pos, 1.0), View).xyz;


	//set sphere
	Sphere ball;
	ball.center = float3(0, 0, 0);
	ball.redius = 1.0;
	ball.color = float3(0.9, 0.9, 0.5);

	//set light
	float3 LightColor = float3(1.0, 1.0, 1.0);
	float3 LightDir = float3(1.0, 0.0, 0.0);

	//采用相交测试，对未相交像素，返回背景色
	float3 r_o = ball.center - ray.pos;
	float r_o_len = length(r_o);
	float r_t_len = dot(ray.dir, r_o);
	float o_t_len2 = r_o_len*r_o_len - r_t_len*r_t_len;
	float len = 0;
	float3 bgcolor = GetBGColor(xy);
	if (o_t_len2 > ball.redius*ball.redius)
	{
		return bgcolor;
	}
	else
	{
		len = r_t_len - pow(ball.redius*ball.redius - o_t_len2, 0.5);
		ray.pos += len * ray.dir;
		len = 0;
	}

	//在球体内进行步进
	float alpha = 0;
	float3 sumCol = (float3)0;
	for (int i = 0; i < 40; i++)
	{
		len = Length(ray.pos, ball);
		if (len > DELTA + ball.redius || alpha >= 1)	//穿出小球或颜色累积足够
		{
			break;
		}
		else		//步进累计颜色
		{
			ray.pos += ray.dir*0.05;
			float density = FractalNoise3D(ray.pos, 1.8);
			float dist = distance(ray.pos, ball.center);
			float3 localCol = GetVoxelColor(density, dist) * density;

			sumCol += localCol * (1 - alpha);
			alpha += density * (1 - alpha);

		}
	}

	alpha = clamp(0, 1, alpha);
	sumCol = lerp(bgcolor, sumCol, alpha);

	return sumCol;
}

//=======================================3D Cloud=============================//
matrix SetViewMatrix(float3 eye, float3 at)
{
	//set View matrix
	float3 up = float3(0.0, 1.0, 0.0);

	matrix trans = (matrix)0; trans[3] = float4(eye, 1.0); trans[0][0] = trans[1][1] = trans[2][2] = trans[3][3] = 1;

	float3 front = normalize((at - eye).xyz);
	float3 right = cross(up, front);
	up = cross(front, right);

	matrix rotate = (matrix)0; rotate[0] = float4(right, 0.0); rotate[1] = float4(up, 0.0); rotate[2] = float4(front, 0.0); rotate[3][3] = 1;

	return mul(trans, rotate);
}

float3 GetCloudVoxelColor(float density, float dist)
{
	return lerp(float3(0.9, 0.8, 0.7), float3(0.5, 0.6, 0.5), density*density);
}

float3 Get3DCloudColor(float2 xy)
{
	float3 eye = float3(0, 5, -10);
	float3 at = float3(0, 2, 0);
	matrix View = SetViewMatrix(eye, at);

	//set ray
	Ray ray;
	ray.dir = normalize(float3(xy, 1.732));		//y方向fov为60度
	ray.pos = float3(0, 0, 0);

	ray.dir = mul(float4(ray.dir, 0.0), View).xyz;		//变换射线位置和方向
	ray.pos = mul(float4(ray.pos, 1.0), View).xyz;

	//cloud height range: (0, 2)
	//采用相交测试，对未相交像素，返回背景色
	float len = 0;
	float3 bgcolor = GetSkyColor(xy);
	if (abs(ray.dir.y) <= DELTA)		//与云层平行
	{
		return bgcolor;
	}
	
	len = -3 / ray.dir.y;
	if (len < 0)	//视线远离云层
	{
		return bgcolor;
	}

	ray.pos += len *ray.dir;

	//在云层内进行步进
	float alpha = 0;
	float3 sumCol = (float3)0;
	for (int i = 0; i < 40; i++)
	{
		if (ray.pos.y < 0 || alpha >= 1)	//穿出小球或颜色累积足够
		{
			break;
		}
		else		//步进累计颜色
		{
			ray.pos += ray.dir*0.05;
			float density = FractalNoise3D(ray.pos, 1.8);
			float3 localCol = GetCloudVoxelColor(density, 0) * density;

			sumCol += localCol * (1 - alpha);
			alpha += density * (1 - alpha);

		}
	}

	alpha = clamp(0, 1, alpha);
	sumCol = lerp(bgcolor, sumCol, alpha);

	return sumCol;
}

//=================================Main函数===================================//
float4 main(PS_INPUT input) : SV_TARGET
{
	////========================vary color=======================//
	//////zero point in the center
	//float2 xy = input.xy;
	//float minLen = min(ScreenWidth, ScreenHeight);
	//xy = xy / minLen * 2;			//y : -1,1;
	//float3 color = GetVaryColor(xy);

	//==========================ray matching=======================//
	////zero point in the bottom left
	//float2 xy = input.xy * 2 / float2(ScreenHeight, ScreenHeight);		y:(-1,1)
	//float3 color = RayMatching(xy);

	//=========================perlin noise==========================//
	//float2 xy = input.xy + float2(ScreenWidth, ScreenHeight) / 2.0;		//xy : (0, 0) - (screenWidth, screenHeight);
	//float3 color;
	//float gray = PerlinNoise2D(xy, 0.03);
	//gray = (gray + 1)*0.5;
	//gray = clamp(gray, 0, 1);
	//color.rgb = float3(gray, gray, gray);

	//=============================cloud=============================//
	//float2 xy = input.xy + float2(ScreenWidth, ScreenHeight) / 2.0;		//xy : (0, 0) - (screenWidth, screenHeight);
	//float gray = FractalNoise2D(xy, 0.01);
	//float3 color = float3(gray, gray, gray);
	//float3 skyCol = float3(0.0, 0.75, 0.9);
	//color = lerp(skyCol, color, gray);

	////=============================Some Texture=============================//
	//float2 xy = input.xy + float2(ScreenWidth, ScreenHeight) / 2.0;		//xy : (0, 0) - (screenWidth, screenHeight);
	//float gray = Turbulence(xy, 0.01);
	//float3 color = float3(gray, gray, gray);

	////================================3D Perlin noise===============================//
	//float2 xy = input.xy + float2(ScreenWidth, ScreenHeight) / 2.0;		//xyz : (0, 0, 0) - (screenWidth, screenHeight, screenHeight);
	//float gray = FractalNoise3D(float3(xy, 0), 0.03);
	//float3 color = float3(gray, gray, gray);

	////==========================Volumetric render=======================//
	//float2 xy = input.xy * 2 / float2(ScreenHeight, ScreenHeight);
	//float3 color = Volumetric(xy);

	////==========================3D Cloud render=======================//
	float2 xy = input.xy * 2 / float2(ScreenHeight, ScreenHeight);
	float3 color = Get3DCloudColor(xy);

	return float4(color, 1.0);
}