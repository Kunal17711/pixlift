"""SRVGGNetCompact architecture.

Copied from Real-ESRGAN (BSD-3-Clause, (c) 2021 Xintao Wang):
  https://github.com/xinntao/Real-ESRGAN/blob/master/realesrgan/archs/srvgg_arch.py

Used only to translate the released PyTorch checkpoint into ONNX. See
THIRD_PARTY_NOTICES.md for attribution.
"""

import torch
from torch import nn as nn
from torch.nn import functional as F


class SRVGGNetCompact(nn.Module):
    """A compact VGG-style network structure for super-resolution."""

    def __init__(self, num_in_ch=3, num_out_ch=3, num_feat=64, num_conv=16, upscale=4, act_type="prelu"):
        super().__init__()
        self.num_in_ch = num_in_ch
        self.num_out_ch = num_out_ch
        self.num_feat = num_feat
        self.num_conv = num_conv
        self.upscale = upscale
        self.act_type = act_type

        self.body = nn.ModuleList()
        self.body.append(nn.Conv2d(num_in_ch, num_feat, 3, 1, 1))
        self.body.append(self._activation(act_type, num_feat))

        for _ in range(num_conv):
            self.body.append(nn.Conv2d(num_feat, num_feat, 3, 1, 1))
            self.body.append(self._activation(act_type, num_feat))

        self.body.append(nn.Conv2d(num_feat, num_out_ch * upscale * upscale, 3, 1, 1))
        self.upsampler = nn.PixelShuffle(upscale)

    @staticmethod
    def _activation(act_type, num_feat):
        if act_type == "relu":
            return nn.ReLU(inplace=True)
        if act_type == "prelu":
            return nn.PReLU(num_parameters=num_feat)
        if act_type == "leakyrelu":
            return nn.LeakyReLU(negative_slope=0.1, inplace=True)
        raise ValueError(f"unknown activation {act_type}")

    def forward(self, x):
        out = x
        for module in self.body:
            out = module(out)
        out = self.upsampler(out)
        base = F.interpolate(x, scale_factor=self.upscale, mode="nearest")
        out += base
        return out


def load_released_state(state_dict, strip_prefix="params_ema."):
    """Strip released Real-ESRGAN checkpoint wrappers (params / params_ema)."""
    key = None
    for candidate in ("params_ema", "params"):
        if candidate in state_dict:
            key = candidate
            break
    if key is None:
        return state_dict
    stripped = {}
    for k, v in state_dict[key].items():
        stripped[k[len(strip_prefix):] if k.startswith(strip_prefix) else k] = v
    return stripped