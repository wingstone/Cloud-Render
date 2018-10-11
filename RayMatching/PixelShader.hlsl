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

//=======================Varied Color===========================//
float3 GetVaryColor(float2 xy)
{
	float3 color = 0.5 + 0.5*sin(xy.xyx + float3(0, 2, 4) + Time);

	return color;
}

//=======================3D Perlin Noise================================//
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
	int index = frac(dot(float2(ix, iy), float2(413.23, 635.21))) * 12;		//random index
	float3 grad = Gradiant[index];

	return dot(grad, float3(x, y, 0));	
}

float dotGridGradient3D(int3 pos, float3 fract)
{
	int index = frac(dot(pos, float3(413.23, 635.21, 463.15))) * 12;		//random index
	float3 grad = Gradiant[index];

		return dot(grad, fract);
}

//xy : (0, 0) - (screenWidth, screenHeight);
float PerlinNoise2D(float2 xy, float frequency)		//pixel coord
{
	xy = xy * frequency;

	int x0 = floor(xy.x);
	int y0 = floor(xy.y);

	float dx = xy.x - x0;
	float dy = xy.y - y0;

	int x1 = x0 + 1;
	int y1 = y0 + 1;

	float4 noise;
	noise.x = dotGridGradient2D(x0, y0, dx, dy);
	noise.y = dotGridGradient2D(x0, y1, dx, dy - 1);
	noise.z = dotGridGradient2D(x1, y0, dx - 1, dy);
	noise.w = dotGridGradient2D(x1, y1, dx - 1, dy - 1);

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

	float4 noise0, noise1;

	int x1 = x0 + 1;
	int y1 = y0 + 1;
	int z1 = z0 + 1;

	noise0.x = dotGridGradient3D(int3(x0, y0, z0), float3(dx, dy, dz));
	noise0.y = dotGridGradient3D(int3(x0, y1, z0), float3(dx, dy - 1.0, dz));
	noise0.z = dotGridGradient3D(int3(x1, y0, z0), float3(dx - 1.0, dy, dz));
	noise0.w = dotGridGradient3D(int3(x1, y1, z0), float3(dx - 1.0, dy - 1.0, dz));

	noise1.x = dotGridGradient3D(int3(x0, y0, z1), float3(dx, dy, dz - 1.0));
	noise1.y = dotGridGradient3D(int3(x0, y1, z1), float3(dx, dy - 1.0, dz - 1.0));
	noise1.z = dotGridGradient3D(int3(x1, y0, z1), float3(dx - 1.0, dy, dz - 1.0));
	noise1.w = dotGridGradient3D(int3(x1, y1, z1), float3(dx - 1.0, dy - 1.0, dz - 1.0));
	
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
//分形叠加后的perlin noise
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
//一个简单的球体体渲染
float3 GetVoxelColor(float density, float dist)
{
	return lerp(float3(0.9, 0.8, 0.7), float3(0.4, 0.1, 0.05), density*density);
}

float3 Volumetric(float2 xy)
{
	//set View matrix
	float3 cameraPos = float3(5 * sin(Time*0.5), 0.0, 5.0*cos(Time*0.5));
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
	ball.redius = 1.5;
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
	sumCol += bgcolor*(1- alpha);

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

float3 GetSkyColor(float3 rayDir, float3 sunDir, float3 sunCol)
{
	float3 skyCol = float3(0.53, 0.81, 0.98);

	float factor = dot(rayDir, sunDir);
	skyCol = lerp(skyCol, sunCol, smoothstep(0.75, 1.0, factor*factor)*0.8);
	skyCol = lerp(skyCol, sunCol, smoothstep(0.95, 0.96, factor*factor));
	return skyCol;
}

float GetLocalDensity(float3 pos, float2 mid_width)
{
	float density = FractalNoise3D(pos, 0.08);
	float dist = abs(pos.y - mid_width.x);
	density *= smoothstep(0, 1, mid_width.y / 2 - dist)*0.8;		//根据高度调整密度

	density += 0.003;
	return saturate(density);
}

float3 GetLocalLight(float3 pos, float density, float2 mid_width, float3 sunCol)
{
	sunCol *= 110.0f;
	float dist = 100 - pos.y;			//到光源的距离
	float3 dir = float3(0.0, 1.0, 0.0);
	float3 light = sunCol/ dist;		//计算当地光

	float shadow = 1.0f;
	float shadowNum = 5.0;
	float step = mid_width.y / shadowNum;
	//考虑阴影
	for (float i = 0.5; i < shadowNum; i++)
	{
		float density = GetLocalDensity(pos+dir*i*step, mid_width);
		shadow *= exp(-step*density*0.3);
	}
	light *= shadow;
	return light;
}

float3 Get3DCloudColor(float2 xy)
{
	float3 eye = float3(0, 0, -30);
	float3 at = float3(0, 20, 0);
	matrix View = SetViewMatrix(eye, at);

	//set ray
	Ray ray;
	ray.dir = normalize(float3(xy, 1.732));		//y方向fov为60度
	ray.pos = float3(0, 0, 0);

	ray.dir = mul(float4(ray.dir, 0.0), View).xyz;		//变换射线位置和方向
	ray.pos = mul(float4(ray.pos, 1.0), View).xyz;

	//采用相交测试，对未相交像素，返回背景色
	float2 range = float2(6, 12);
	float len = 0;
	float3 sunPos = float3(50.0, 100.0, 100.0);
	float3 sunDir = normalize(sunPos - ray.pos);
	float3 sunCol = float3(1.0, 0.98, 0.9);
	float3 bgcolor = GetSkyColor(ray.dir, sunDir, sunCol);
	if (abs(ray.dir.y) <= DELTA)		//与云层平行
	{
		return bgcolor;
	}
	
	len = (range.x - ray.pos.y) / ray.dir.y;
	if (len < 0)	//视线远离云层
	{
		return bgcolor;
	}

	ray.pos = ray.pos + ray.dir*len;

	//在云层内进行步进
	float3 sumCol = (float3)0;
	float2 mid_width = float2((range.x + range.y) / 2, range.y - range.x);
	float t = 1.0;
	float transmittance = 1.0f;
	for (int i = 0; i < 16; i++)
	{
		if (ray.pos.y > range.y )	//穿出云层
		{
			break;
		}
		else		//步进累计颜色
		{
			ray.pos += ray.dir*t;
			float density = GetLocalDensity(ray.pos, mid_width);
			float3 localCol = GetLocalLight(ray.pos, density, mid_width, sunCol) * (1.0f - exp(-density*t));

			sumCol += localCol * transmittance;
			transmittance *= exp(-t*density);

		}
	}
	sumCol += bgcolor*transmittance;

	float3 fogColor = float3(1.0, 1.00, 0.94);
	float factor = clamp(0, 1, (distance(eye, ray.pos) - 64.0)/ 100.0);
	sumCol = lerp(sumCol, fogColor, factor);

	return sumCol;
}

//=================================Main函数===================================//
//可以通过注释不同的代码来获取不同的基本效果~
//
float4 main(PS_INPUT input) : SV_TARGET
{
	////========================vary color=======================//
	//////zero point in the center
	//float2 xy = input.xy;
	//float minLen = min(ScreenWidth, ScreenHeight);
	//xy = xy / minLen * 2;			//y : -1,1;
	//float3 color = GetVaryColor(xy);

	//=========================perlin noise==========================//
	//float2 xy = input.xy + float2(ScreenWidth, ScreenHeight) / 2.0;		//xy : (0, 0) - (screenWidth, screenHeight);
	//float3 color;
	//float gray = PerlinNoise2D(xy, 0.03);
	//gray = (gray + 1)*0.5;
	//gray = clamp(gray, 0, 1);
	//color.rgb = float3(gray, gray, gray);

	//=============================cloud=============================//
	//2D 云
	//float2 xy = input.xy + float2(ScreenWidth, ScreenHeight) / 2.0;		//xy : (0, 0) - (screenWidth, screenHeight);
	//float gray = FractalNoise2D(xy, 0.01)+0.1;
	//float3 color = float3(gray, gray, gray);
	//float3 skyCol = float3(0.0, 0.75, 0.9);
	//color = color * gray + skyCol*(1.0- gray);

	////=============================Some Texture=============================//
	//模拟湍流效果
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