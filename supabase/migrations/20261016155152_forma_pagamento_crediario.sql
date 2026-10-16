-- Crediário (fiado): nova forma de pagamento. Fica numa migration própria
-- porque um valor novo de enum só pode ser usado depois de gravado.
alter type public.forma_pagamento add value if not exists 'crediario';
