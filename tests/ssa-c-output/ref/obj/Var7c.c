#include "./Var7c.d"
#include "__oo2c.h"

static OOC_INT16 Var7c__Len(OOC_CHAR8 str[]) {
  register OOC_INT32 i0,i1;

  i0=-1;
l1_loop:
  i0 = i0+1;
  
  i1 = (OOC_INT32)str+i0;
  i1 = *(OOC_UINT8*)i1;
  i1 = i1=='\000';
  if (!i1) goto l1_loop;
  i0 = i0+0;
  return i0;
}

void Var7c__Test() {
  register OOC_INT32 i0;

  i0 = Var7c__Len("");
  Out__Int(i0, 0);
  Out__Ln();
  i0 = Var7c__Len("abc");
  Out__Int(i0, 0);
  Out__Ln();
  return;
}

void Var7c_init(void) {
}
