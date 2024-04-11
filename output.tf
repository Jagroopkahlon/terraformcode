output "terraformLB_2" {
    value = aws_lb.terraformLB_2.dns_name
}

output "publicip_1instance" {
  value = aws_instance.Hellojagroop.public_ip
}