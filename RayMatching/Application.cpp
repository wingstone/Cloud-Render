#include "Application.h"

LRESULT CALLBACK Application::WinProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	switch (message)
	{
	case WM_DESTROY:
		PostQuitMessage(0);
		break;
	case WM_KEYDOWN:
		if (wParam == VK_ESCAPE)
			DestroyWindow( hwnd );
		break;
	default:
		return DefWindowProc(hwnd, message, wParam, lParam);
	}

	return 0;
}

Application::Application()
{
	_device = nullptr;
	_swapChain = nullptr;
	_context = nullptr;

	_renderTargetView = nullptr;
	_depthTexture = nullptr;
	_depthStencilView = nullptr;

	_vertexShader = nullptr;
	_InputLayout = nullptr;
	_pixelShader = nullptr;

	_vertexBuffer = nullptr;
	_indexBuffer = nullptr;
}

Application::~Application()
{}

bool Application::Initial(HINSTANCE hInstance, bool windowed)
{
	WNDCLASS wc;
	memset(&wc, 0, sizeof(WNDCLASS));
	wc.style = CS_HREDRAW | CS_VREDRAW;
	wc.lpfnWndProc = Application::WinProc;
	wc.hInstance = hInstance;
	wc.lpszMenuName = nullptr;
	wc.lpszClassName = "WinClass";

	RegisterClass(&wc);

	_hwnd = CreateWindow("WinClass",
		"RayMatching Window",
		WS_OVERLAPPEDWINDOW,
		CW_USEDEFAULT, 
		CW_USEDEFAULT,
		SCREENWIDTH,
		SCREENHEIGHT, 
		0,
		0, 
		hInstance, 
		0);
	if (!_hwnd)
	{
		return false;
	}

	_screenWidth = SCREENWIDTH;
	_screenHeight = SCREENHEIGHT;

	if(!InitialD3D())
		return false;

	if (!InitialShader())
		return false;

	if (!InitialBuffer())
		return false;

	ShowWindow(_hwnd, SW_SHOW);
	UpdateWindow(_hwnd);

	return true;
}

int Application::MainLoop()
{
	MSG msg;
	memset(&msg, 0, sizeof(MSG));

	float currentTime = GetTickCount() / 1000.0f;
	float lastTime = currentTime;
	float deltTime = 0.0f;

	while (msg.message != WM_QUIT)
	{
		if (PeekMessage(&msg, 0, 0, 0, PM_REMOVE))
		{
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}
		else
		{
			currentTime = GetTickCount() / 1000.0f;
			deltTime = currentTime - lastTime;
			Render(deltTime);
			lastTime = currentTime;
		}
	}

	return (int)msg.wParam;
}

void Application::Quit()
{
	SAFE_RELEASE(_vertexShader);
	 SAFE_RELEASE(_InputLayout);
	SAFE_RELEASE(_pixelShader);

	SAFE_RELEASE(_vertexBuffer);
	SAFE_RELEASE(_indexBuffer);

	SAFE_RELEASE(_timeBuffer);
	SAFE_RELEASE(_matrixBuffer);
	SAFE_RELEASE(_depthStencilView);
	SAFE_RELEASE(_renderTargetView);
	SAFE_RELEASE(_depthTexture);
	SAFE_RELEASE(_swapChain);
	SAFE_RELEASE(_context);
	SAFE_RELEASE(_device);
}

bool Application::InitialD3D()
{
	HRESULT hr = S_OK;

	//create device and swapchain
	DXGI_SWAP_CHAIN_DESC swapChainDesc;
	memset(&swapChainDesc, 0, sizeof(swapChainDesc));
	swapChainDesc.BufferCount = 1;
	swapChainDesc.BufferDesc.Width = _screenWidth;
	swapChainDesc.BufferDesc.Height = _screenHeight;
	swapChainDesc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	swapChainDesc.BufferDesc.Scaling = DXGI_MODE_SCALING_UNSPECIFIED;
	swapChainDesc.BufferDesc.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
	swapChainDesc.BufferDesc.RefreshRate.Numerator = 0;
	swapChainDesc.BufferDesc.RefreshRate.Denominator = 1;
	swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	swapChainDesc.Flags = 0;
	swapChainDesc.OutputWindow = _hwnd;
	swapChainDesc.SampleDesc.Count = 1;
	swapChainDesc.SampleDesc.Quality = 0;
	swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
	swapChainDesc.Windowed = TRUE;

	D3D_DRIVER_TYPE driverType[] =
	{
		D3D_DRIVER_TYPE_HARDWARE,
		D3D_DRIVER_TYPE_WARP,
	};
	D3D_FEATURE_LEVEL featureLevels[] =
	{
		D3D_FEATURE_LEVEL_11_0,
		D3D_FEATURE_LEVEL_10_1,
		D3D_FEATURE_LEVEL_10_0,
	};
	for (int i = 0; i < ARRAYSIZE(driverType); i++)
	{
		hr = D3D11CreateDeviceAndSwapChain(nullptr, driverType[i], 0, 0, featureLevels, 3, D3D11_SDK_VERSION, &swapChainDesc, &_swapChain, &_device, &_featureLevel, &_context);
		if (SUCCEEDED(hr))
			break;
	}
	if (FAILED(hr))
		return false;

	//创建RenderTargetView
	ID3D11Texture2D *resource;
	_swapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&resource);
	_device->CreateRenderTargetView(resource, nullptr, &_renderTargetView);
	SAFE_RELEASE(resource);

	//创建DepthStencilView
	D3D11_TEXTURE2D_DESC depthDesc;
	memset(&depthDesc, 0, sizeof(depthDesc));
	depthDesc.Width = _screenWidth;
	depthDesc.Height = _screenHeight;
	depthDesc.MipLevels = 1;
	depthDesc.ArraySize = 1;
	depthDesc.Format = DXGI_FORMAT_D24_UNORM_S8_UINT;
	depthDesc.SampleDesc.Count = 1;
	depthDesc.SampleDesc.Quality = 0;
	depthDesc.Usage = D3D11_USAGE_DEFAULT;	
	depthDesc.BindFlags = D3D11_BIND_DEPTH_STENCIL;
	depthDesc.CPUAccessFlags = 0;
	depthDesc.MiscFlags = 0;
	_device->CreateTexture2D(&depthDesc, nullptr, &_depthTexture);

	D3D11_DEPTH_STENCIL_VIEW_DESC depthStencilViewDesc;
	memset(&depthStencilViewDesc, 0, sizeof(depthStencilViewDesc));
	depthStencilViewDesc.Format = depthDesc.Format;
	depthStencilViewDesc.ViewDimension = D3D11_DSV_DIMENSION_TEXTURE2D;
	depthStencilViewDesc.Texture2D.MipSlice = 0;
	_device->CreateDepthStencilView(_depthTexture, &depthStencilViewDesc, &_depthStencilView);

	_context->OMSetRenderTargets(1, &_renderTargetView, _depthStencilView);
	
	//创建ViewPort
	D3D11_VIEWPORT viewPort;
	viewPort.Width = (float)_screenWidth;
	viewPort.Height = (float)_screenHeight;
	viewPort.TopLeftX = 0.0f;
	viewPort.TopLeftY = 0.0f;
	viewPort.MinDepth = 0.0f;
	viewPort.MaxDepth = 1.0f;
	_context->RSSetViewports(1, &viewPort);

	return true;
}

bool Application::InitialShader()
{
	HRESULT hr = S_OK;

	//create shader
	ID3DBlob* vertexBlob;
	ID3DBlob* pixelBlob;
	ID3DBlob* errorMessage = nullptr;

	//从已编译好的cso文件中加载shader
#ifdef _DEBUG
	//重新从文本文件中编译shader
	hr = D3DCompileFromFile(L"VertexShader.hlsl", nullptr, nullptr, "main", "vs_5_0", D3DCOMPILE_ENABLE_STRICTNESS, 0, &vertexBlob, &errorMessage);
	if (FAILED(hr))
	{
		MessageBox(nullptr, (char*)errorMessage->GetBufferPointer(), nullptr, MB_OK);
		SAFE_RELEASE(errorMessage);
		return false;
	}
	hr = D3DCompileFromFile(L"PixelShader.hlsl", nullptr, nullptr, "main", "ps_5_0", D3DCOMPILE_ENABLE_STRICTNESS, 0, &pixelBlob, &errorMessage);
	if (FAILED(hr))
	{
		MessageBox(nullptr, (char*)errorMessage->GetBufferPointer(), nullptr, MB_OK);
		SAFE_RELEASE(errorMessage);
		return false;
	}
#else
	hr = D3DReadFileToBlob(L"VertexShader.cso", &vertexBlob);
	if (FAILED(hr))
		return false;
	
	hr = D3DReadFileToBlob(L"PixelShader.cso", &pixelBlob);
	if (FAILED(hr))
		return false;
#endif

	hr = _device->CreateVertexShader(vertexBlob->GetBufferPointer(), vertexBlob->GetBufferSize(), nullptr, &_vertexShader);
	if (FAILED(hr))
	{
		MessageBox(nullptr, "can't create vertex shader", nullptr, MB_OK);
		SAFE_RELEASE(errorMessage);
		return false;
	}

	hr = _device->CreatePixelShader(pixelBlob->GetBufferPointer(), pixelBlob->GetBufferSize(), nullptr, &_pixelShader);
	if (FAILED(hr))
	{
		MessageBox(nullptr, "can't create pixel shader", nullptr, MB_OK);
		SAFE_RELEASE(errorMessage);
		return false;
	}

	//create input
	D3D11_INPUT_ELEMENT_DESC inputDesc[] =
	{
		{ "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
	};
	hr = _device->CreateInputLayout(inputDesc, ARRAYSIZE(inputDesc), vertexBlob->GetBufferPointer(), vertexBlob->GetBufferSize(), &_InputLayout);
	if (FAILED(hr))
	{
		MessageBox(nullptr, "can't create pixel shader", nullptr, MB_OK);
		SAFE_RELEASE(errorMessage);
		return false;
	}

	SAFE_RELEASE(vertexBlob);
	SAFE_RELEASE(pixelBlob);
	SAFE_RELEASE(errorMessage);

	return true;
}

bool Application::InitialBuffer()
{
	HRESULT hr = S_OK;

	//create vertex buffer
	XMFLOAT3 vertexData[] =
	{
		XMFLOAT3(_screenWidth / -2.0f, _screenHeight / -2.0f, 0.0f),
		XMFLOAT3(_screenWidth / -2.0f, _screenHeight / 2.0f, 0.0f),
		XMFLOAT3(_screenWidth / 2.0f, _screenHeight / 2.0f, 0.0f),
		XMFLOAT3(_screenWidth / 2.0f, _screenHeight / -2.0f, 0.0f),
	};
	D3D11_SUBRESOURCE_DATA initData;
	initData.pSysMem = vertexData;

	D3D11_BUFFER_DESC vertexBufferDesc;
	ZeroMemory(&vertexBufferDesc, sizeof(vertexBufferDesc));
	vertexBufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	vertexBufferDesc.ByteWidth = sizeof(vertexData);
	vertexBufferDesc.CPUAccessFlags = 0;
	vertexBufferDesc.MiscFlags = 0;
	vertexBufferDesc.StructureByteStride = sizeof(XMFLOAT3);
	vertexBufferDesc.Usage = D3D11_USAGE_DEFAULT;

	hr = _device->CreateBuffer(&vertexBufferDesc, &initData, &_vertexBuffer);
	if (FAILED(hr))
	{
		MessageBox(nullptr, "can't create Vertex buffer", nullptr, MB_OK);
		return false;
	}

	//create index buffer
	DWORD IndexData[] =
	{
		0, 1, 2,
		0, 2, 3,
	};

	D3D11_BUFFER_DESC indexBufferDesc;
	ZeroMemory(&indexBufferDesc, sizeof(indexBufferDesc));
	indexBufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
	indexBufferDesc.ByteWidth = sizeof(IndexData);
	indexBufferDesc.CPUAccessFlags = 0;
	indexBufferDesc.MiscFlags = 0;
	indexBufferDesc.StructureByteStride = sizeof(DWORD);
	indexBufferDesc.Usage = D3D11_USAGE_DEFAULT;

	initData.pSysMem = IndexData;
	hr = _device->CreateBuffer(&indexBufferDesc, &initData, &_indexBuffer);
	if (FAILED(hr))
	{
		MessageBox(nullptr, "can't create index buffer", nullptr, MB_OK);
		return false;
	}

	//create const buffer
	D3D11_BUFFER_DESC constBufferDesc;
	ZeroMemory(&constBufferDesc, sizeof(constBufferDesc));
	constBufferDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	constBufferDesc.ByteWidth = sizeof(MATRIXSTRUCT);
	constBufferDesc.CPUAccessFlags = 0;
	constBufferDesc.MiscFlags = 0;
	constBufferDesc.Usage = D3D11_USAGE_DEFAULT;

	hr = _device->CreateBuffer(&constBufferDesc, nullptr, &_matrixBuffer);
	if (FAILED(hr))
	{
		MessageBox(nullptr, "can't create const buffer", nullptr, MB_OK);
		return false;
	}

	MATRIXSTRUCT mat;
	mat.Model = XMMatrixIdentity();
	XMVECTOR eye = XMVectorSet(0.0f, 0.0f, -10.0f, 1.0f);
	XMVECTOR at = XMVectorSet(0.0f, 0.0f, 0.0f, 1.0f);
	XMVECTOR up = XMVectorSet(0.0f, 1.0f, 0.0f, 0.0f);
	mat.View = XMMatrixLookAtLH(eye, at, up);
	mat.View = XMMatrixTranspose(mat.View);
	mat.Projection = XMMatrixOrthographicLH((float)_screenWidth, (float)_screenHeight, 0.1f, 100.0f);
	mat.Projection = XMMatrixTranspose(mat.Projection);
	_context->UpdateSubresource(_matrixBuffer, 0, nullptr, &mat, 0, 0);

	constBufferDesc.ByteWidth = sizeof(TIMESTRUCT);
	hr = _device->CreateBuffer(&constBufferDesc, nullptr, &_timeBuffer);
	if (FAILED(hr))
	{
		MessageBox(nullptr, "can't create const buffer", nullptr, MB_OK);
		return false;
	}

	return true;
}

void Application::Render(float deltTime)
{
	float color[] = { 0.0f, 0.0f, 0.0f, 0.0f };
	_context->ClearRenderTargetView(_renderTargetView, color);
	_context->ClearDepthStencilView(_depthStencilView, D3D11_CLEAR_DEPTH, 1.0f, 0);

	UINT stride[] = { sizeof(XMFLOAT3) };
	UINT offset[] = { 0 };
	_context->IASetInputLayout(_InputLayout);
	_context->IASetVertexBuffers(0, 1, &_vertexBuffer, stride, offset);
	_context->IASetIndexBuffer(_indexBuffer, DXGI_FORMAT_R32_UINT, 0);
	_context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

	_context->VSSetShader(_vertexShader, nullptr, 0);
	_context->VSSetConstantBuffers(0, 1, &_matrixBuffer);

	static float currentTime = 0;
	currentTime += deltTime;
	TIMESTRUCT timebuffer;
	timebuffer.Time = currentTime;
	timebuffer.ScreenWidth = (float)_screenWidth;
	timebuffer.ScreenHeight = (float)_screenHeight;
	_context->UpdateSubresource(_timeBuffer, 0, nullptr, &timebuffer, 0, 0);
	_context->PSSetShader(_pixelShader, nullptr, 0);
	_context->PSSetConstantBuffers(0, 1, &_timeBuffer);

	_context->DrawIndexed(6, 0, 0);

	_swapChain->Present(0, 0);

}