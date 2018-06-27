cbuffer matbuffer
{
	matrix Model;
	matrix View;
	matrix Projection;
};

struct VS_INPUT
{
	float3 Pos : POSITION;
};

struct PS_INPUT
{
	float4 Pos : SV_POSITION;
	float2 xy : TEXCOORD0;
};

PS_INPUT main(VS_INPUT input)
{
	PS_INPUT output;

	output.Pos = mul(float4(input.Pos, 1.0), Model);
	output.Pos = mul(output.Pos, View);
	output.Pos = mul(output.Pos, Projection);

	output.xy = input.Pos.xy;

	return output;
}