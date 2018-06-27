#include <windows.h>
#include "Application.h"

int WINAPI WinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance, _In_ LPTSTR lpCmdLine, _In_ int nCmdShow)
{
	Application app;
	if (!app.Initial(hInstance, true))
	{
		MessageBox(nullptr, "Can't initial App!", nullptr, MB_OK);
		return 0;
	}

	int wParam = app.MainLoop();

	app.Quit();

	return wParam;
}