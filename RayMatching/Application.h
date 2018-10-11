#include <windows.h>
#include <d3d11.h>
#include <d3dcommon.h>
#include <DirectXMath.h>
#include <d3dcompiler.h>

#include "Commen.h"

#define SCREENWIDTH 640
#define SCREENHEIGHT 480

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "d3dcompiler.lib")

using namespace DirectX;

class Application
{
public:
	Application();
	Application(const Application& other);
	~Application();

	bool Initial(HINSTANCE hInstance, bool windowed);
	int MainLoop();
	void Render(float deltTime);
	void Quit();

private:
	bool InitialD3D();
	bool InitialShader();
	bool InitialBuffer();
	static LRESULT CALLBACK WinProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);

private:
	UINT _screenWidth;
	UINT _screenHeight;
	HWND _hwnd;

	ID3D11Device *_device;
	IDXGISwapChain* _swapChain;
	ID3D11DeviceContext* _context;
	D3D_FEATURE_LEVEL _featureLevel;

	ID3D11RenderTargetView* _renderTargetView;
	ID3D11Texture2D* _depthTexture;
	ID3D11DepthStencilView* _depthStencilView;

	ID3D11VertexShader* _vertexShader;
	ID3D11InputLayout* _InputLayout;
	ID3D11PixelShader* _pixelShader;

	ID3D11Buffer* _vertexBuffer;
	ID3D11Buffer* _indexBuffer;

	ID3D11Buffer* _timeBuffer;
	ID3D11Buffer* _matrixBuffer;

private:
	struct MATRIXSTRUCT
	{
		XMMATRIX Model;
		XMMATRIX View;
		XMMATRIX Projection;
	};
	struct TIMESTRUCT
	{
		float Time;
		float ScreenWidth;
		float ScreenHeight;
		float padding;
	};
};
